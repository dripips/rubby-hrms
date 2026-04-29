import { Controller } from "@hotwired/stimulus"

// On change of an employee <select>, fetches that employee's quota + leave
// history HTML and replaces the panel target. Works inside any form (full
// new-leave page, quick-leave modal, etc.).
export default class extends Controller {
  static targets = ["select", "panel"]
  static values  = { url: String }

  connect()  { this._maybeLoad() }
  refresh()  { this._maybeLoad() }

  async _maybeLoad() {
    if (!this.hasSelectTarget || !this.hasPanelTarget) return
    const id = this.selectTarget.value
    if (!id) {
      this.panelTarget.innerHTML = ""
      return
    }
    const url = `${this.urlValue}?employee_id=${encodeURIComponent(id)}`
    try {
      this.panelTarget.classList.add("is-loading")
      const res = await fetch(url, { headers: { Accept: "text/html, */*" } })
      if (!res.ok) {
        this.panelTarget.innerHTML = ""
        return
      }
      this.panelTarget.innerHTML = await res.text()
    } catch (e) {
      console.warn("[employee-leave-panel] fetch failed", e)
    } finally {
      this.panelTarget.classList.remove("is-loading")
    }
  }
}
