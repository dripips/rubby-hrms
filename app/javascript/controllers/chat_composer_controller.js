import { Controller } from "@hotwired/stimulus"

// Enter → submit (без Shift), Shift+Enter → новая строка.
// После успешного submit Turbo Stream подменяет #composer на свежий
// (пустой) textarea — поэтому фокус возвращаем после rerender.
export default class extends Controller {
  static targets = ["input"]

  connect() {
    this._refocusOn = () => this.inputTarget?.focus()
    document.addEventListener("turbo:morph", this._refocusOn)
    document.addEventListener("turbo:before-stream-render", this._refocusOn)
  }

  disconnect() {
    document.removeEventListener("turbo:morph", this._refocusOn)
    document.removeEventListener("turbo:before-stream-render", this._refocusOn)
  }

  onKeydown(e) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault()
      this.element.requestSubmit()
    }
  }
}
