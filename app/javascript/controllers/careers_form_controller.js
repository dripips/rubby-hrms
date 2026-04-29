import { Controller } from "@hotwired/stimulus"

// Careers application form: auto-save в localStorage + восстановление черновика
// + smooth scroll к первой ошибке после неудачного submit'а.
//
// <form data-controller="careers-form" data-careers-form-storage-key-value="careers_app_OPENING_ID">
//   <input name="job_applicant[first_name]" data-careers-form-target="field">
//   …
// </form>
export default class extends Controller {
  static values  = { storageKey: String }
  static targets = ["field", "restoreNote"]

  connect() {
    this._restoreDraft()
    this._scrollToFirstError()

    this._onChange = this._onChange.bind(this)
    this._onSubmit = this._onSubmit.bind(this)
    this.element.addEventListener("input",  this._onChange)
    this.element.addEventListener("change", this._onChange)
    this.element.addEventListener("submit", this._onSubmit)
  }

  disconnect() {
    this.element.removeEventListener("input",  this._onChange)
    this.element.removeEventListener("change", this._onChange)
    this.element.removeEventListener("submit", this._onSubmit)
  }

  _onChange(event) {
    const target = event.target
    if (!target.name || target.type === "file" || target.type === "submit") return
    this._saveDraft()
  }

  _onSubmit() {
    // На успешный submit — очищаем черновик. Если запрос вернёт ошибку
    // (validation), Turbo нас оставит на той же странице, и значения уже в
    // полях — повторный auto-save их сохранит.
    try { localStorage.removeItem(this._storageKey()) } catch {}
  }

  _saveDraft() {
    const data = {}
    this.element.querySelectorAll("input[name], textarea[name], select[name]").forEach(el => {
      if (el.type === "file" || el.type === "submit" || el.name === "authenticity_token" || el.name === "website") return
      if (el.type === "checkbox") {
        data[el.name] = el.checked ? "1" : "0"
      } else {
        data[el.name] = el.value
      }
    })
    try {
      localStorage.setItem(this._storageKey(), JSON.stringify({ d: data, at: Date.now() }))
    } catch {}
  }

  _restoreDraft() {
    let payload
    try { payload = JSON.parse(localStorage.getItem(this._storageKey()) || "null") } catch {}
    if (!payload || !payload.d) return

    // Если форма уже частично заполнена (server-rendered после ошибки) — не перезаписываем
    let alreadyFilled = false
    this.element.querySelectorAll("input[name], textarea[name]").forEach(el => {
      if (["file", "submit", "hidden"].includes(el.type)) return
      if (el.value && el.value.trim() !== "") alreadyFilled = true
    })

    if (alreadyFilled) return

    Object.entries(payload.d).forEach(([name, value]) => {
      const el = this.element.querySelector(`[name="${CSS.escape(name)}"]`)
      if (!el) return
      if (el.type === "checkbox") {
        el.checked = value === "1"
      } else if (el.type !== "file") {
        el.value = value
      }
    })

    if (this.hasRestoreNoteTarget) {
      this.restoreNoteTarget.hidden = false
    }
  }

  clearDraft(event) {
    event?.preventDefault?.()
    try { localStorage.removeItem(this._storageKey()) } catch {}
    this.element.reset()
    if (this.hasRestoreNoteTarget) this.restoreNoteTarget.hidden = true
  }

  _scrollToFirstError() {
    const firstError = this.element.querySelector(".careers-form__field.has-error, .careers-form__errors")
    if (!firstError) return
    requestAnimationFrame(() => {
      firstError.scrollIntoView({ behavior: "smooth", block: "center" })
      const inputInside = firstError.querySelector("input, textarea, select")
      inputInside?.focus({ preventScroll: true })
    })
  }

  _storageKey() {
    return this.storageKeyValue || "careers_application_draft"
  }
}
