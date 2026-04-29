import { Controller } from "@hotwired/stimulus"

// Универсальный vertical/horizontal tabs Stimulus контроллер.
//
// <div data-controller="settings-tabs">
//   <button data-settings-tabs-target="tab" data-tab-name="general" data-action="click->settings-tabs#switch">General</button>
//   <button data-settings-tabs-target="tab" data-tab-name="api">API</button>
//   <div data-settings-tabs-target="panel" data-tab="general">…</div>
//   <div data-settings-tabs-target="panel" data-tab="api">…</div>
// </div>
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    const fromHash = window.location.hash.replace("#", "")
    const stored   = sessionStorage.getItem(this._storageKey())
    const initial  = this.tabTargets.find(t => t.dataset.tabName === fromHash) ||
                     this.tabTargets.find(t => t.dataset.tabName === stored) ||
                     this.tabTargets[0]
    if (initial) this._activate(initial.dataset.tabName, { persist: false })
  }

  switch(event) {
    event.preventDefault()
    const name = event.currentTarget.dataset.tabName
    if (!name) return
    this._activate(name, { persist: true })
    history.replaceState(null, "", `#${name}`)
  }

  _activate(name, { persist } = {}) {
    this.tabTargets.forEach(t => t.classList.toggle("is-active", t.dataset.tabName === name))
    this.panelTargets.forEach(p => p.classList.toggle("is-active", p.dataset.tab === name))
    if (persist) sessionStorage.setItem(this._storageKey(), name)
  }

  _storageKey() {
    return `settings-tabs:${window.location.pathname}`
  }
}
