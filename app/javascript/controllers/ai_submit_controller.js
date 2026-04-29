import { Controller } from "@hotwired/stimulus"

// Мгновенно блокирует кнопку при клике, чтобы юзер не успел нажать дважды
// до прихода turbo-response. Сервер всё равно проверяет AiLock, это просто
// прозрачный UX-щит от двойного запуска.
export default class extends Controller {
  busy(event) {
    const form = event.target.closest("form") || event.target
    const buttons = form.querySelectorAll("button[type=submit], input[type=submit]")
    buttons.forEach((btn) => {
      btn.disabled = true
      btn.dataset.originalText ||= btn.textContent
      btn.classList.add("is-busy")
    })
  }
}
