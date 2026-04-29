import { Controller } from "@hotwired/stimulus"

// Запоминаем последний активный таб per-applicant в sessionStorage.
// Приоритет восстановления при connect():
//   1. URL hash (#interviews, #notes, ...) — явное намерение
//   2. sessionStorage — последний выбор пользователя на этой странице
//   3. первый таб (профиль) — fallback
//
// Это решает проблему со stage-change / form-submit редиректами:
// после любого редиректа на ту же страницу таб остаётся тот же.
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values  = { storageKey: { type: String, default: "" } }

  connect() {
    const hash    = window.location.hash.replace("#", "")
    const stored  = this._readStored()
    const fromHash    = this.tabTargets.find(t => t.dataset.tab === hash)
    const fromStorage = this.tabTargets.find(t => t.dataset.tab === stored)
    const initial = fromHash || fromStorage || this.tabTargets[0]
    this._activate(initial?.dataset.tab, { persist: false })
  }

  switch(event) {
    event.preventDefault()
    const name = event.currentTarget.dataset.tab
    this._activate(name, { persist: true })
    history.replaceState(null, "", `#${name}`)
  }

  _activate(name, { persist } = { persist: false }) {
    if (!name) return
    this.tabTargets.forEach(t => t.classList.toggle("is-active", t.dataset.tab === name))
    this.panelTargets.forEach(p => p.classList.toggle("is-active", p.dataset.tab === name))
    if (persist) this._writeStored(name)
  }

  _storageKey() {
    return this.storageKeyValue || `applicant-tabs:${window.location.pathname}`
  }

  _readStored() {
    try { return sessionStorage.getItem(this._storageKey()) } catch { return null }
  }

  _writeStored(name) {
    try { sessionStorage.setItem(this._storageKey(), name) } catch { /* ignore */ }
  }
}
