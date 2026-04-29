import { Controller } from "@hotwired/stimulus"

// Bootstrap-модалка с авто-закрытием на успешный Turbo-сабмит.
//
// Доп. фикс: телепортируем элемент в <body> при mount, чтобы position: fixed
// корректно ставил модалку относительно viewport. Иначе любой transformed/
// filtered/contain-ed предок (animation, will-change, transform на .card-apple
// hover-стейт и т.д.) делает fixed-предок containing-block — модалка
// открывается "криво" внутри страницы вместо overlay'а.
export default class extends Controller {
  connect() {
    this._teleportToBody()

    this._onSubmitEnd       = this._onSubmitEnd.bind(this)
    this._onBeforeStream    = this._onBeforeStream.bind(this)
    this.element.addEventListener("turbo:submit-end", this._onSubmitEnd)
    document.addEventListener("turbo:before-stream-render", this._onBeforeStream)
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-end", this._onSubmitEnd)
    document.removeEventListener("turbo:before-stream-render", this._onBeforeStream)
    this._observer?.disconnect()
    // Если nas нативный disconnect — модалка удаляется вместе с DOM, не трогаем.
  }

  // Перемещает модалку в <body> и навешивает MutationObserver на исходного
  // родителя — если он будет удалён (Turbo Stream replace), мы тоже удаляем
  // нашу телепортированную модалку, чтобы не оставлять "ауф-оф-синк" дубли.
  _teleportToBody() {
    if (this.element.parentElement === document.body) return

    const originalParent = this.element.parentElement
    if (!originalParent) return

    // Помечаем элемент уникальным id для дебага.
    this.element.dataset.teleported = "1"

    document.body.appendChild(this.element)

    // Когда исходный родитель исчезает — убираем модалку из body.
    this._observer = new MutationObserver(() => {
      if (!originalParent.isConnected) {
        this.element.remove()
        this._observer.disconnect()
      }
    })
    // Наблюдаем за удалениями выше: достаточно следить за document.body.
    this._observer.observe(document.body, { childList: true, subtree: true })
  }

  _onSubmitEnd(event) {
    if (event.detail?.success) this._hide()
  }

  _onBeforeStream(_event) {
    if (this.element.classList.contains("show")) this._hide()
  }

  _hide() {
    const Modal = window.bootstrap?.Modal
    if (!Modal) return

    const instance = Modal.getInstance(this.element)
    instance?.hide()

    this.element.querySelectorAll("form").forEach((form) => {
      requestAnimationFrame(() => form.reset())
    })
  }
}
