import { Controller } from "@hotwired/stimulus"

// Apple-style календарь-picker для <input type="date"> и <input type="datetime-local">.
// Без внешних библиотек. Native picker скрывается, показывается кастом-trigger.
// При клике открывается dropdown с месячной сеткой + (опционально) timepicker.
//
// Использование:
//   <input type="date" data-controller="apple-date-picker">
//   <input type="datetime-local" data-controller="apple-date-picker">
export default class extends Controller {
  connect() {
    this._input = this.element
    if (!["date", "datetime-local"].includes(this._input.type)) return

    this._isDateTime = this._input.type === "datetime-local"
    this._locale     = document.documentElement.lang || "ru"
    this._firstDay   = (this._locale === "ru") ? 1 : 0  // ru: пн, en: вс

    this._renderTrigger()
    this._renderPanel()
    this._refreshTrigger()

    this._onDocClick = this._onDocClick.bind(this)
    this._onKey      = this._onKey.bind(this)
    this._onInputChange = this._onInputChange.bind(this)
    document.addEventListener("click",   this._onDocClick)
    document.addEventListener("keydown", this._onKey)
    this._input.addEventListener("change", this._onInputChange)
  }

  disconnect() {
    document.removeEventListener("click",   this._onDocClick)
    document.removeEventListener("keydown", this._onKey)
    this._input?.removeEventListener("change", this._onInputChange)
    this._panel?.remove()
  }

  // ─── Render ────────────────────────────────────────────────────────────
  _renderTrigger() {
    if (this._input.closest(".apple-date-picker")) return  // идемпотентность

    const wrapper = document.createElement("div")
    wrapper.className = "apple-date-picker"

    const trigger = document.createElement("button")
    trigger.type = "button"
    trigger.className = "apple-date-picker__trigger"
    trigger.setAttribute("aria-haspopup", "dialog")

    const icon = document.createElement("span")
    icon.className = "apple-date-picker__icon"
    icon.innerHTML = `<svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><rect x="2" y="3.5" width="12" height="11" rx="1.5"/><path d="M2 7h12M5 2v3M11 2v3"/></svg>`
    trigger.appendChild(icon)

    const display = document.createElement("span")
    display.className = "apple-date-picker__display"
    trigger.appendChild(display)

    trigger.addEventListener("click", (e) => { e.preventDefault(); this.toggle() })

    this._input.parentElement.insertBefore(wrapper, this._input)
    wrapper.appendChild(trigger)
    wrapper.appendChild(this._input)
    this._input.classList.add("apple-date-picker__source")
    this._input.tabIndex = -1

    if (this._input.id) {
      const label = document.querySelector(`label[for="${this._input.id}"]`)
      if (label) label.addEventListener("click", (e) => { e.preventDefault(); trigger.focus(); this.open() })
    }

    this._wrapper = wrapper
    this._trigger = trigger
    this._display = display
  }

  _renderPanel() {
    const panel = document.createElement("div")
    panel.className = "apple-date-picker__panel"
    panel.setAttribute("role", "dialog")
    panel.hidden = true

    panel.innerHTML = `
      <header class="apple-date-picker__head">
        <button type="button" class="apple-date-picker__nav" data-action="prev" aria-label="Prev month">‹</button>
        <button type="button" class="apple-date-picker__title" data-action="title"></button>
        <button type="button" class="apple-date-picker__nav" data-action="next" aria-label="Next month">›</button>
      </header>
      <div class="apple-date-picker__weekdays"></div>
      <div class="apple-date-picker__grid"></div>
      ${this._isDateTime ? `
        <div class="apple-date-picker__time">
          <label>Время</label>
          <input type="time" class="apple-date-picker__time-input" step="60">
        </div>
      ` : ""}
      <footer class="apple-date-picker__foot">
        <button type="button" class="btn btn-ghost btn-sm" data-action="today">Сегодня</button>
        <button type="button" class="btn btn-ghost btn-sm" data-action="clear">Очистить</button>
      </footer>
    `

    panel.addEventListener("click", (e) => {
      const action = e.target.closest("[data-action]")?.dataset?.action
      if (!action) return
      switch (action) {
        case "prev":   e.preventDefault(); this._shiftMonth(-1); break
        case "next":   e.preventDefault(); this._shiftMonth(1); break
        case "title":  e.preventDefault(); this._gotoToday(); break
        case "today":  e.preventDefault(); this._pickDate(new Date()); break
        case "clear":  e.preventDefault(); this._clear(); break
      }
    })

    if (this._isDateTime) {
      const ti = panel.querySelector(".apple-date-picker__time-input")
      ti.addEventListener("change", () => this._onTimeChange(ti.value))
      this._timeInput = ti
    }

    document.body.appendChild(panel)
    this._panel = panel
    this._weekdaysEl = panel.querySelector(".apple-date-picker__weekdays")
    this._gridEl     = panel.querySelector(".apple-date-picker__grid")
    this._titleEl    = panel.querySelector(".apple-date-picker__title")
  }

  _renderWeekdays() {
    if (!this._weekdaysEl) return
    this._weekdaysEl.innerHTML = ""
    const ref = new Date(2024, 0, 1)  // Mon Jan 1, 2024
    for (let i = 0; i < 7; i++) {
      const d = new Date(ref)
      d.setDate(ref.getDate() + (this._firstDay + i))  // 1..7 from Mon
      const span = document.createElement("span")
      span.textContent = new Intl.DateTimeFormat(this._locale, { weekday: "short" }).format(d).slice(0, 2)
      this._weekdaysEl.appendChild(span)
    }
  }

  _renderGrid() {
    if (!this._gridEl) return
    this._gridEl.innerHTML = ""

    const view  = this._viewDate
    const year  = view.getFullYear()
    const month = view.getMonth()
    const first = new Date(year, month, 1)
    const last  = new Date(year, month + 1, 0)

    // Сдвиг до первой ячейки сетки (понедельник или воскресенье)
    let leadDay = (first.getDay() - this._firstDay + 7) % 7
    const startDay = new Date(year, month, 1 - leadDay)

    const today = this._stripTime(new Date())
    const sel   = this._currentValue() ? this._stripTime(this._currentValue()) : null

    for (let i = 0; i < 42; i++) {
      const d = new Date(startDay)
      d.setDate(startDay.getDate() + i)
      const inMonth = d.getMonth() === month

      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "apple-date-picker__day"
      if (!inMonth) btn.classList.add("is-other")
      if (this._sameDay(d, today)) btn.classList.add("is-today")
      if (sel && this._sameDay(d, sel)) btn.classList.add("is-selected")
      btn.textContent = d.getDate()
      btn.dataset.iso = this._isoDate(d)
      btn.addEventListener("click", (e) => {
        e.preventDefault()
        this._pickDate(d)
      })
      this._gridEl.appendChild(btn)
    }

    if (this._titleEl) {
      this._titleEl.textContent = new Intl.DateTimeFormat(this._locale, {
        month: "long", year: "numeric"
      }).format(view)
    }
  }

  // ─── Public API ────────────────────────────────────────────────────────
  toggle() { this.isOpen ? this.close() : this.open() }

  open() {
    if (!this._panel) return
    this._viewDate = this._currentValue() || new Date()
    this._renderWeekdays()
    this._renderGrid()
    if (this._isDateTime && this._timeInput) {
      const v = this._currentValue()
      if (v) this._timeInput.value = `${this._pad(v.getHours())}:${this._pad(v.getMinutes())}`
    }
    this._panel.hidden = false
    this._position()
    requestAnimationFrame(() => this._panel.classList.add("is-visible"))
    this._trigger?.setAttribute("aria-expanded", "true")
    this.isOpen = true
  }

  close() {
    if (!this._panel) return
    this._panel.classList.remove("is-visible")
    setTimeout(() => { if (this._panel) this._panel.hidden = true }, 140)
    this._trigger?.setAttribute("aria-expanded", "false")
    this.isOpen = false
  }

  // ─── Internal ─────────────────────────────────────────────────────────
  _currentValue() {
    const v = this._input.value
    if (!v) return null
    return this._isDateTime ? new Date(v) : new Date(v + "T00:00:00")
  }

  _shiftMonth(delta) {
    this._viewDate = new Date(this._viewDate.getFullYear(), this._viewDate.getMonth() + delta, 1)
    this._renderGrid()
  }

  _gotoToday() {
    this._viewDate = new Date()
    this._renderGrid()
  }

  _pickDate(date) {
    let value
    if (this._isDateTime) {
      const cur = this._currentValue() || new Date()
      const h = cur.getHours(), m = cur.getMinutes()
      const dt = new Date(date.getFullYear(), date.getMonth(), date.getDate(), h, m)
      value = `${this._isoDate(dt)}T${this._pad(dt.getHours())}:${this._pad(dt.getMinutes())}`
    } else {
      value = this._isoDate(date)
    }
    this._input.value = value
    this._input.dispatchEvent(new Event("change", { bubbles: true }))
    this._refreshTrigger()
    if (!this._isDateTime) this.close()
    else this._renderGrid()  // подсветить выбранный день
  }

  _onTimeChange(timeStr) {
    if (!timeStr) return
    const cur = this._currentValue() || new Date()
    const [hh, mm] = timeStr.split(":").map(Number)
    cur.setHours(hh, mm, 0, 0)
    this._input.value = `${this._isoDate(cur)}T${this._pad(hh)}:${this._pad(mm)}`
    this._input.dispatchEvent(new Event("change", { bubbles: true }))
    this._refreshTrigger()
  }

  _clear() {
    this._input.value = ""
    this._input.dispatchEvent(new Event("change", { bubbles: true }))
    this._refreshTrigger()
    this.close()
  }

  _refreshTrigger() {
    if (!this._display) return
    const v = this._currentValue()
    if (!v) {
      this._display.textContent = this._isDateTime ? "Выберите дату и время" : "Выберите дату"
      this._display.classList.add("is-empty")
      return
    }
    this._display.classList.remove("is-empty")
    if (this._isDateTime) {
      this._display.textContent = new Intl.DateTimeFormat(this._locale, {
        day: "numeric", month: "short", year: "numeric",
        hour: "2-digit", minute: "2-digit"
      }).format(v)
    } else {
      this._display.textContent = new Intl.DateTimeFormat(this._locale, {
        day: "numeric", month: "long", year: "numeric"
      }).format(v)
    }
  }

  _onInputChange() {
    this._refreshTrigger()
    if (this._panel && !this._panel.hidden) this._renderGrid()
  }

  _position() {
    if (!this._panel || !this._wrapper) return
    const rect = this._wrapper.getBoundingClientRect()
    const margin = 6
    let top  = rect.bottom + margin
    let left = rect.left
    const width = 280
    if (left + width > window.innerWidth - 12) left = window.innerWidth - width - 12
    this._panel.style.left = `${Math.max(8, left)}px`
    this._panel.style.top  = `${top}px`
    requestAnimationFrame(() => {
      const ph = this._panel.offsetHeight
      if (top + ph > window.innerHeight - 12) {
        this._panel.style.top = `${Math.max(8, rect.top - ph - margin)}px`
      }
    })
  }

  _onDocClick(e) {
    if (!this.isOpen) return
    if (this._panel?.contains(e.target))   return
    if (this._wrapper?.contains(e.target)) return
    this.close()
  }

  _onKey(e) {
    if (!this.isOpen) return
    if (e.key === "Escape") { e.preventDefault(); this.close() }
  }

  _stripTime(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate()) }
  _sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate() }
  _pad(n) { return String(n).padStart(2, "0") }
  _isoDate(d) { return `${d.getFullYear()}-${this._pad(d.getMonth() + 1)}-${this._pad(d.getDate())}` }
}
