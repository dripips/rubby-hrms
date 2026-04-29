import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { after: { type: Number, default: 4500 } }

  connect() {
    if (this.afterValue > 0) {
      this.timeout = setTimeout(() => this.close(), this.afterValue)
    }
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  close() {
    this.element.classList.add("is-leaving")
    this.element.addEventListener("transitionend", () => this.element.remove(), { once: true })
    setTimeout(() => this.element.remove(), 320)
  }
}
