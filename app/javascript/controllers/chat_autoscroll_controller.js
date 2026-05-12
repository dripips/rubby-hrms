import { Controller } from "@hotwired/stimulus"

// Скроллит чат вниз при загрузке + при добавлении нового сообщения.
// MutationObserver ловит turbo-stream append, потому что Turbo не отдаёт
// событие напрямую на конкретный node.
export default class extends Controller {
  connect() {
    this._scrollBottom()
    this._observer = new MutationObserver(() => this._scrollBottom())
    this._observer.observe(this.element, { childList: true })
  }

  disconnect() { this._observer?.disconnect() }

  _scrollBottom() {
    requestAnimationFrame(() => {
      this.element.scrollTop = this.element.scrollHeight
    })
  }
}
