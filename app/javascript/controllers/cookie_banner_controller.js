import { Controller } from "@hotwired/stimulus"

// Cookie consent banner: показывается если в cookie нет ранее сохранённого выбора.
// Хранит выбор в cookie name из value `storageKey`. Структура: { categories: [...], at: ts }
export default class extends Controller {
  static targets = ["categories", "checkbox", "customizeBtn", "acceptBtn", "saveBtn"]
  static values  = { storageKey: { type: String, default: "careers_cookie_consent" } }

  connect() {
    if (!this._existingChoice()) {
      requestAnimationFrame(() => {
        this.element.hidden = false
        requestAnimationFrame(() => this.element.classList.add("is-visible"))
      })
    }
  }

  showCategories() {
    if (!this.hasCategoriesTarget) return
    this.categoriesTarget.hidden = false
    if (this.hasCustomizeBtnTarget) this.customizeBtnTarget.hidden = true
    if (this.hasAcceptBtnTarget)    this.acceptBtnTarget.hidden = true
    if (this.hasSaveBtnTarget)      this.saveBtnTarget.hidden = false
  }

  acceptAll() {
    const all = this.checkboxTargets.map(cb => cb.value)
    this._save(all)
  }

  essentialOnly() {
    const required = this.checkboxTargets.filter(cb => cb.disabled).map(cb => cb.value)
    this._save(required)
  }

  saveSelection() {
    const picked = this.checkboxTargets.filter(cb => cb.checked).map(cb => cb.value)
    this._save(picked)
  }

  _save(categories) {
    const payload = JSON.stringify({ categories, at: Date.now() })
    document.cookie = `${this.storageKeyValue}=${encodeURIComponent(payload)};path=/;max-age=${365*24*60*60};samesite=Lax`
    this.element.classList.remove("is-visible")
    setTimeout(() => { this.element.hidden = true }, 220)
  }

  _existingChoice() {
    const m = document.cookie.match(new RegExp(`(?:^|; )${this.storageKeyValue}=([^;]+)`))
    if (!m) return null
    try { return JSON.parse(decodeURIComponent(m[1])) } catch { return null }
  }
}
