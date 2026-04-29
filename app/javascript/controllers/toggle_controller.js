import { Controller } from "@hotwired/stimulus"

// Простой переключатель видимости целевого селектора по состоянию чекбокса.
// Использование:
//   <input type="checkbox" data-controller="toggle"
//          data-toggle-target-value="#paymentBlock">
//   <div id="paymentBlock" style="display: none;">...</div>
export default class extends Controller {
  static values = { target: String }

  connect() {
    this.element.addEventListener("change", () => this.sync())
    this.sync()
  }

  sync() {
    const target = document.querySelector(this.targetValue)
    if (!target) return
    target.style.display = this.element.checked ? "" : "none"
  }
}
