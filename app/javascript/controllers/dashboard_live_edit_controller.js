import { Controller } from "@hotwired/stimulus"

// Inline iOS-style edit mode для дашборда:
//  • кнопка "Изменить" → on/off режим (виджеты wiggle, оверлеи появляются)
//  • drag-and-drop reorder с live-relayout грида
//  • size-segment pips в углу каждого виджета — клик меняет класс мгновенно
//  • eye-toggle — скрывает/показывает (visually dim в edit-mode, удаляется на сохранении)
//  • sticky bar внизу с Сохранить / Отмена
//  • Cancel восстанавливает изначальное состояние через snapshot
export default class extends Controller {
  static targets = ["grid", "editBar", "enterButton"]
  static values  = { saveUrl: String }

  connect() {
    this._snapshot = null
    this._dragging = null

    this._onDragStart = this._onDragStart.bind(this)
    this._onDragOver  = this._onDragOver.bind(this)
    this._onDragEnd   = this._onDragEnd.bind(this)
    this._onKeydown   = this._onKeydown.bind(this)
  }

  // ── Edit mode ──────────────────────────────────────────────────────────
  enter(event) {
    event?.preventDefault?.()
    this._snapshot = this._capture()
    this.gridTarget.classList.add("is-edit-mode")
    if (this.hasEditBarTarget)     this.editBarTarget.hidden     = false
    if (this.hasEnterButtonTarget) this.enterButtonTarget.hidden = true

    this.gridTarget.addEventListener("dragstart", this._onDragStart)
    this.gridTarget.addEventListener("dragover",  this._onDragOver)
    this.gridTarget.addEventListener("dragend",   this._onDragEnd)
    document.addEventListener("keydown", this._onKeydown)
  }

  exit() {
    this.gridTarget.classList.remove("is-edit-mode")
    if (this.hasEditBarTarget)     this.editBarTarget.hidden     = true
    if (this.hasEnterButtonTarget) this.enterButtonTarget.hidden = false

    this.gridTarget.removeEventListener("dragstart", this._onDragStart)
    this.gridTarget.removeEventListener("dragover",  this._onDragOver)
    this.gridTarget.removeEventListener("dragend",   this._onDragEnd)
    document.removeEventListener("keydown", this._onKeydown)
  }

  cancel(event) {
    event?.preventDefault?.()
    if (this._snapshot) this._restore(this._snapshot)
    this._snapshot = null
    this.exit()
  }

  async save(event) {
    event?.preventDefault?.()
    const formData = new FormData()
    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    if (csrf) formData.append("authenticity_token", csrf)

    this._widgets().forEach((el) => {
      const key    = el.dataset.widgetKey
      const size   = el.dataset.size
      const hidden = el.dataset.hidden === "true"

      formData.append("order[]", key)
      formData.append(`sizes[${key}]`, size)
      if (hidden) formData.append("hidden[]", key)
    })

    try {
      const response = await fetch(this.saveUrlValue, {
        method:  "POST",
        body:    formData,
        credentials: "same-origin",
        headers: { Accept: "text/html" },
        redirect: "manual"  // сами решаем что делать с 302
      })

      // Сервер делает redirect_to dashboard_path после save — это для нас сигнал OK.
      if (response.ok || response.status === 0 || response.type === "opaqueredirect") {
        this._snapshot = null
        this.exit()
        // Удаляем теперь-настояще-скрытые виджеты из DOM (post-save они не должны мелькать)
        this._widgets().forEach((el) => {
          if (el.dataset.hidden === "true") el.remove()
        })
        this._toast(this._t("saved", "Сохранено"))
      } else {
        this._toast(this._t("save_failed", "Не получилось сохранить"))
      }
    } catch (_err) {
      this._toast(this._t("save_failed", "Не получилось сохранить"))
    }
  }

  // ── Resize via size pip click ──────────────────────────────────────────
  resize(event) {
    const radio = event.target
    if (!radio || radio.type !== "radio") return
    const widget = radio.closest("[data-widget-key]")
    if (!widget) return

    const newSize = radio.value
    widget.classList.remove("dashboard-widget--s", "dashboard-widget--m", "dashboard-widget--l")
    widget.classList.add(`dashboard-widget--${newSize}`)
    widget.dataset.size = newSize

    // Toggle is-active на pip'ах
    const segment = radio.closest(".size-segment")
    segment?.querySelectorAll(".size-segment__pip").forEach((p) => p.classList.remove("is-active"))
    radio.closest(".size-segment__pip")?.classList.add("is-active")
  }

  // ── Eye toggle ──────────────────────────────────────────────────────────
  toggleVisibility(event) {
    event.preventDefault()
    const widget = event.currentTarget.closest("[data-widget-key]")
    if (!widget) return
    const next = widget.dataset.hidden !== "true"
    widget.dataset.hidden = String(next)
    widget.classList.toggle("is-hidden", next)
    event.currentTarget.setAttribute("aria-pressed", String(next))
  }

  // ── Drag-and-drop reorder (insertion-based) ────────────────────────────
  _onDragStart(e) {
    const item = e.target.closest("[data-widget-key]")
    if (!item) return
    this._dragging = item
    item.classList.add("is-dragging")
    e.dataTransfer.effectAllowed = "move"
    e.dataTransfer.setData("text/plain", item.dataset.widgetKey || "")
  }

  _onDragOver(e) {
    e.preventDefault()
    if (!this._dragging) return
    const target = e.target.closest("[data-widget-key]")
    if (!target || target === this._dragging) return

    const rect = target.getBoundingClientRect()
    // 2D-сравнение: считаем точку на половине прямоугольника. Если курсор
    // выше или левее (в верхней половине + левой половине) — вставляем перед.
    const midX = rect.left + rect.width  / 2
    const midY = rect.top  + rect.height / 2
    const before = (e.clientY < midY) || (e.clientY < rect.bottom && e.clientX < midX)

    this.gridTarget.insertBefore(this._dragging, before ? target : target.nextSibling)
  }

  _onDragEnd() {
    if (this._dragging) this._dragging.classList.remove("is-dragging")
    this._dragging = null
  }

  _onKeydown(e) {
    if (e.key === "Escape") this.cancel()
  }

  // ── Snapshot helpers ───────────────────────────────────────────────────
  _widgets() {
    return Array.from(this.gridTarget.querySelectorAll("[data-widget-key]"))
  }

  _capture() {
    return this._widgets().map((el) => ({
      key:    el.dataset.widgetKey,
      size:   el.dataset.size,
      hidden: el.dataset.hidden === "true"
    }))
  }

  _restore(snapshot) {
    snapshot.forEach(({ key, size, hidden }) => {
      const el = this.gridTarget.querySelector(`[data-widget-key="${CSS.escape(key)}"]`)
      if (!el) return
      this.gridTarget.appendChild(el)
      el.classList.remove("dashboard-widget--s", "dashboard-widget--m", "dashboard-widget--l")
      el.classList.add(`dashboard-widget--${size}`)
      el.dataset.size = size
      el.dataset.hidden = String(hidden)
      el.classList.toggle("is-hidden", hidden)

      // restore checked state of size pips
      el.querySelectorAll(".size-segment__pip").forEach((p) => p.classList.remove("is-active"))
      const radio = el.querySelector(`input[type="radio"][value="${size}"]`)
      if (radio) {
        radio.checked = true
        radio.closest(".size-segment__pip")?.classList.add("is-active")
      }
    })
  }

  // ── Toast (минималистичный) ─────────────────────────────────────────────
  _toast(text) {
    const toast = document.createElement("div")
    toast.className = "toast-apple toast-apple--bottom"
    toast.textContent = text
    document.body.appendChild(toast)
    requestAnimationFrame(() => toast.classList.add("is-visible"))
    setTimeout(() => {
      toast.classList.remove("is-visible")
      setTimeout(() => toast.remove(), 300)
    }, 1800)
  }

  _t(key, fallback) {
    const el = this.element.querySelector(`[data-i18n="${key}"]`)
    return el?.textContent || fallback
  }
}
