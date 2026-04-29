import { Controller } from "@hotwired/stimulus"

// Универсальный Apple-style dropdown — заменяет нативный <select> overlay
// на styled-panel. Подключается к существующему <select> или к обёртке
// с `<select>` внутри.
//
// Использование:
//   1) Прямо на <select>:
//      <select data-controller="apple-select" class="form-select">...</select>
//      Контроллер обернёт select и сгенерит trigger + panel автоматически.
//
//   2) Внутри chip-обёртки (filter-chip):
//      <label class="filter-chip" data-controller="apple-select">
//        <span data-apple-select-target="display">...</span>
//        <select data-apple-select-target="source">...</select>
//      </label>
//      Контроллер найдёт source-select и display-target, добавит panel.
//
// На пик опции:
//   • устанавливает select.value
//   • диспатчит "change" event на нативном select (существующие data-action работают)
//   • обновляет display-target
//   • закрывает panel
export default class extends Controller {
  static targets = ["source", "display", "panel"]

  connect() {
    this._setup()
    this._onDocClick = this._onDocClick.bind(this)
    this._onKey      = this._onKey.bind(this)
    this._onSrcChange = this._onSrcChange.bind(this)
    document.addEventListener("click",   this._onDocClick)
    document.addEventListener("keydown", this._onKey)
    this._select?.addEventListener("change", this._onSrcChange)
  }

  disconnect() {
    document.removeEventListener("click",   this._onDocClick)
    document.removeEventListener("keydown", this._onKey)
    this._select?.removeEventListener("change", this._onSrcChange)
    this._panel?.remove()
    // НЕ удаляем _wrapper — он содержит сам source-select (controller element).
    // Удаление wrapper'а вырвало бы select из DOM, ломая форму.
  }

  // Внешний код (resetFilters и т.п.) может менять select.value и
  // диспатчить change — ловим и обновляем UI.
  _onSrcChange() {
    this._syncDisplay()
    this._refreshHighlight()
  }

  _setup() {
    // Найти нативный <select>: либо явный target, либо сам this.element, либо
    // первый <select> внутри.
    if (this.hasSourceTarget) {
      this._select = this.sourceTarget
    } else if (this.element.tagName === "SELECT") {
      this._select = this.element
    } else {
      this._select = this.element.querySelector("select")
    }
    if (!this._select) return

    // display-target — где обновлять видимый текст. Если нет — рендерим
    // полную обёртку (trigger + display) над select'ом.
    if (this.hasDisplayTarget) {
      this._display = this.displayTarget
      this._renderPanelOnly()
    } else {
      // Идемпотентность: если select уже внутри .apple-select wrapper'а
      // (например, при reconnect), переиспользуем существующий trigger/panel.
      const existing = this._select.closest(".apple-select")
      if (existing && existing.dataset.appleSelectGenerated === "1") {
        this._wrapper = existing
        this._trigger = existing.querySelector(".apple-select__trigger")
        this._display = existing.querySelector(".apple-select__display")
        this._renderPanel(existing)
      } else {
        this._renderFullWrapper()
      }
    }
    this._syncDisplay()
  }

  // Случай 1 — нет filter-chip обёртки: оборачиваем select полностью.
  _renderFullWrapper() {
    const wrapper = document.createElement("div")
    wrapper.className = "apple-select"
    wrapper.dataset.appleSelectGenerated = "1"

    const trigger = document.createElement("button")
    trigger.type = "button"
    trigger.className = "apple-select__trigger"
    trigger.setAttribute("aria-haspopup", "listbox")
    trigger.setAttribute("aria-expanded", "false")

    const display = document.createElement("span")
    display.className = "apple-select__display"
    trigger.appendChild(display)

    const chevron = document.createElement("span")
    chevron.className = "apple-select__chev"
    chevron.textContent = "▾"
    trigger.appendChild(chevron)

    trigger.addEventListener("click", (e) => { e.preventDefault(); this.toggle() })

    // Прячем нативный select, не убираем из DOM (он сабмиттится в форме)
    this._select.parentElement.insertBefore(wrapper, this._select)
    wrapper.appendChild(trigger)
    wrapper.appendChild(this._select)
    this._select.classList.add("apple-select__source")

    // Доступность: tab фокусирует наш trigger, не скрытый select
    this._select.tabIndex = -1

    // Label[for=id] — клик должен открывать кастом-panel, иначе focus летит
    // в скрытый select и ничего не происходит.
    if (this._select.id) {
      const label = document.querySelector(`label[for="${this._select.id}"]`)
      if (label) {
        label.addEventListener("click", (e) => {
          e.preventDefault()
          trigger.focus()
          this.open()
        })
      }
    }

    this._display = display
    this._trigger = trigger
    this._wrapper = wrapper
    this._renderPanel(wrapper)
  }

  // Случай 2 — есть filter-chip обёртка с display-target внутри.
  _renderPanelOnly() {
    // Кликабельная зона — корневой элемент контроллера (filter-chip label)
    this.element.addEventListener("click", (e) => {
      // Игнорим клики по самому скрытому select (он opacity:0 absolute)
      if (e.target.tagName === "SELECT") e.preventDefault()
      e.preventDefault()
      this.toggle()
    })
    this._renderPanel(this.element)
    this._select.classList.add("apple-select__source")
  }

  _renderPanel(anchor) {
    const panel = document.createElement("div")
    panel.className = "apple-select__panel"
    panel.setAttribute("role", "listbox")
    panel.hidden = true

    // Search input — only when there are enough options to justify it.
    // Empty / placeholder option (value="") still counts as 1; require ≥6 real items.
    const realOptions = Array.from(this._select.options).filter(o => o.value !== "")
    if (realOptions.length >= 6) {
      const searchWrap = document.createElement("div")
      searchWrap.className = "apple-select__search"
      const searchInput = document.createElement("input")
      searchInput.type = "search"
      searchInput.className = "apple-select__search-input"
      searchInput.placeholder = this._searchPlaceholder()
      searchInput.autocomplete = "off"
      searchInput.spellcheck = false
      searchInput.addEventListener("input", (e) => {
        e.stopPropagation()
        this._applySearch(e.target.value)
      })
      searchInput.addEventListener("click", (e) => e.stopPropagation())
      searchInput.addEventListener("keydown", (e) => {
        // Let the global keydown handler manage Escape/Arrow/Enter
        if (e.key === "Escape" || e.key === "ArrowDown" || e.key === "ArrowUp" || e.key === "Enter") return
        e.stopPropagation()
      })
      searchWrap.appendChild(searchInput)
      panel.appendChild(searchWrap)
      this._searchInput = searchInput
    }

    const list = document.createElement("ul")
    list.className = "apple-select__list"
    panel.appendChild(list)
    this._list = list

    Array.from(this._select.options).forEach((opt, idx) => {
      const item = document.createElement("li")
      item.className = "apple-select__option"
      item.setAttribute("role", "option")
      item.dataset.value = opt.value
      item.dataset.idx   = idx
      item.textContent   = opt.textContent
      if (opt.disabled) item.classList.add("is-disabled")
      if (opt.selected) item.classList.add("is-selected")
      item.addEventListener("click", (e) => {
        e.stopPropagation()
        this._pick(idx)
      })
      list.appendChild(item)
    })

    document.body.appendChild(panel)  // В body чтобы не зависеть от stacking context
    this._panel  = panel
    this._anchor = anchor
  }

  _searchPlaceholder() {
    const html = document.documentElement
    const lang = (html.lang || "en").toLowerCase()
    if (lang.startsWith("ru")) return "Поиск..."
    if (lang.startsWith("de")) return "Suchen..."
    return "Search..."
  }

  _applySearch(query) {
    const q = (query || "").trim().toLowerCase()
    const items = this._list.querySelectorAll(".apple-select__option")
    let firstVisible = -1
    items.forEach((it, i) => {
      const match = q === "" || it.textContent.toLowerCase().includes(q)
      it.classList.toggle("is-hidden", !match)
      if (match && firstVisible < 0) firstVisible = i
    })
    this._highlightIdx = firstVisible >= 0 ? firstVisible : null
    this._refreshHighlight()
  }

  // ─── API ───────────────────────────────────────────────────────────────
  toggle() {
    this.isOpen ? this.close() : this.open()
  }

  open() {
    if (!this._panel) return
    this._panel.hidden = false
    this._position()
    requestAnimationFrame(() => {
      this._panel.classList.add("is-visible")
      // Auto-focus search input if present so user can type immediately.
      if (this._searchInput) {
        this._searchInput.value = ""
        this._applySearch("")
        this._searchInput.focus()
      }
    })
    this._trigger?.setAttribute("aria-expanded", "true")
    this.isOpen = true
    this._highlightIdx = this._select.selectedIndex
    this._refreshHighlight()
  }

  close() {
    if (!this._panel) return
    this._panel.classList.remove("is-visible")
    setTimeout(() => { if (this._panel) this._panel.hidden = true }, 140)
    this._trigger?.setAttribute("aria-expanded", "false")
    this.isOpen = false
  }

  _pick(idx) {
    if (idx < 0 || idx >= this._select.options.length) return
    this._select.selectedIndex = idx
    this._select.dispatchEvent(new Event("change", { bubbles: true }))
    this._syncDisplay()
    this._refreshHighlight()
    this.close()
  }

  _syncDisplay() {
    if (!this._display) return
    const opt = this._select.options[this._select.selectedIndex]
    this._display.textContent = opt ? opt.textContent : ""
  }

  _refreshHighlight() {
    if (!this._panel) return
    const items = this._panel.querySelectorAll(".apple-select__option")
    items.forEach((it, i) => {
      it.classList.toggle("is-selected", i === this._select.selectedIndex)
      it.classList.toggle("is-active",   i === this._highlightIdx)
    })
  }

  // Returns indexes of options that are currently visible (search filter
  // applied). Used by ArrowUp/Down nav to skip hidden rows.
  _visibleIdxs() {
    const items = this._list?.querySelectorAll(".apple-select__option") || []
    const idxs  = []
    items.forEach((it, i) => { if (!it.classList.contains("is-hidden")) idxs.push(i) })
    return idxs
  }

  _position() {
    if (!this._panel || !this._anchor) return
    const rect = this._anchor.getBoundingClientRect()
    const margin = 6

    // Сначала — под триггером, выровненный по левому краю
    let top    = rect.bottom + margin
    let left   = rect.left
    let width  = Math.max(rect.width, 200)

    // Если не помещается по горизонтали — сдвигаем влево
    if (left + width > window.innerWidth - 12) {
      left = window.innerWidth - width - 12
    }

    // Сначала ставим габариты — потом измеряем высоту панели
    this._panel.style.minWidth = `${width}px`
    this._panel.style.left     = `${Math.max(8, left)}px`
    this._panel.style.top      = `${top}px`

    requestAnimationFrame(() => {
      const ph = this._panel.offsetHeight
      // Если не лезет вниз — открываем над триггером
      if (top + ph > window.innerHeight - 12) {
        const upTop = rect.top - ph - margin
        this._panel.style.top = `${Math.max(8, upTop)}px`
      }
    })
  }

  // ─── Outside click + keyboard ──────────────────────────────────────────
  _onDocClick(e) {
    if (!this.isOpen) return
    if (this._panel?.contains(e.target))   return
    if (this._anchor?.contains(e.target))  return
    if (this._wrapper?.contains(e.target)) return
    this.close()
  }

  _onKey(e) {
    if (!this.isOpen) return
    switch (e.key) {
      case "Escape":
        e.preventDefault(); this.close(); break
      case "ArrowDown": {
        e.preventDefault()
        const visible = this._visibleIdxs()
        if (visible.length === 0) break
        const cur = visible.indexOf(this._highlightIdx)
        this._highlightIdx = cur === -1 || cur === visible.length - 1 ? visible[0] : visible[cur + 1]
        this._refreshHighlight(); this._scrollToActive()
        break
      }
      case "ArrowUp": {
        e.preventDefault()
        const visible = this._visibleIdxs()
        if (visible.length === 0) break
        const cur = visible.indexOf(this._highlightIdx)
        this._highlightIdx = cur <= 0 ? visible[visible.length - 1] : visible[cur - 1]
        this._refreshHighlight(); this._scrollToActive()
        break
      }
      case "Enter":
        e.preventDefault()
        if (this._highlightIdx != null) this._pick(this._highlightIdx)
        break
    }
  }

  _scrollToActive() {
    const active = this._panel?.querySelector(".apple-select__option.is-active")
    active?.scrollIntoView({ block: "nearest" })
  }
}
