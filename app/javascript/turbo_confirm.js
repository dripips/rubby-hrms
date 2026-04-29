// Кастомная модалка подтверждения вместо нативного window.confirm.
// Подключается к Turbo через setConfirmMethod; промис разрешается true/false
// в зависимости от выбора пользователя.
//
// Использование:
//   <%= button_to "...", url, method: :delete, data: { turbo_confirm: "Удалить?" } %>
//   <%= link_to "...", url, data: { turbo_confirm: "Удалить?" } %>
// Из произвольного JS:
//   const ok = await window.appConfirm("Точно удалить?", { tone: "danger" })
//
// Опции:
//   tone:        "danger" | "primary" (auto-detect по словам "удал"/"delete")
//   title:       заголовок модалки (по умолчанию из i18n)
//   confirmText: текст confirm-кнопки (default "Подтвердить")
//   cancelText:  текст cancel-кнопки (default "Отмена")

import { Turbo } from "@hotwired/turbo-rails"

const MODAL_ID    = "appConfirmModal"
const DANGER_RE   = /удал|снять|отозв|сброс|delete|remove|discard|destroy/i

let activeResolver = null

function getModal() {
  return document.getElementById(MODAL_ID)
}

function detectTone(message) {
  return DANGER_RE.test(message || "") ? "danger" : "primary"
}

function resetButton(btn, tone) {
  if (!btn) return
  btn.classList.remove("btn-danger", "btn-primary", "btn-soft")
  btn.classList.add("btn", tone === "danger" ? "btn-danger" : "btn-primary")
}

function appConfirm(message, opts = {}) {
  return new Promise((resolve) => {
    const modal = getModal()
    if (!modal || !window.bootstrap?.Modal) {
      resolve(window.confirm(message)) // fallback
      return
    }

    // Если уже была активная конфирмация — разрешаем её отменой.
    if (activeResolver) {
      activeResolver(false)
      activeResolver = null
    }

    const titleEl   = modal.querySelector("[data-confirm-title]")
    const messageEl = modal.querySelector("[data-confirm-message]")
    const confirmBtn = modal.querySelector("[data-confirm-action]")
    const cancelBtn  = modal.querySelector("[data-confirm-cancel]")
    const iconEl     = modal.querySelector("[data-confirm-icon]")

    if (messageEl) {
      messageEl.textContent = message?.trim() || messageEl.dataset.default || "Вы уверены?"
    }
    if (opts.title && titleEl) titleEl.textContent = opts.title
    if (opts.confirmText && confirmBtn) confirmBtn.textContent = opts.confirmText
    if (opts.cancelText  && cancelBtn)  cancelBtn.textContent  = opts.cancelText

    const tone = opts.tone || detectTone(message)
    resetButton(confirmBtn, tone)
    if (iconEl) {
      iconEl.classList.remove("is-danger", "is-primary")
      iconEl.classList.add(`is-${tone}`)
    }

    activeResolver = resolve
    window.bootstrap.Modal.getOrCreateInstance(modal).show()

    // Если поверх другой модалки — поднимаем z-index, чтобы confirm
    // оказался выше parent modal и его backdrop'а.
    const otherOpen = document.querySelectorAll(".modal.show:not(#" + MODAL_ID + ")")
    if (otherOpen.length > 0) {
      modal.style.zIndex = "1085"
      // Свежий backdrop нашего модала — последний в DOM.
      requestAnimationFrame(() => {
        const backdrops = document.querySelectorAll(".modal-backdrop")
        const last = backdrops[backdrops.length - 1]
        if (last) last.style.zIndex = "1080"
      })
    }

    // После открытия — фокус на cancel (безопасный default).
    modal.addEventListener("shown.bs.modal", () => {
      cancelBtn?.focus()
    }, { once: true })
  })
}

function bindModalHandlers() {
  const modal = getModal()
  if (!modal || modal.dataset.confirmBound === "1") return
  modal.dataset.confirmBound = "1"

  modal.addEventListener("click", (e) => {
    if (e.target.closest("[data-confirm-action]")) {
      window.bootstrap?.Modal.getInstance(modal)?.hide()
      // resolve(true) после fade-out, чтобы анимация успела отыграть.
    }
  })

  modal.addEventListener("hide.bs.modal", () => {
    // Запоминаем, что пользователь нажал Подтвердить (по флагу на кнопке).
    // Если hide вызван по cancel/ESC — резолвим false.
  })

  // Реальная резолвция — только после полного закрытия (анимация ~200ms).
  modal.addEventListener("hidden.bs.modal", (event) => {
    // event.detail or other — мы не знаем кто закрыл; по нашей логике
    // данные передаём через флаг.
    const accepted = modal.dataset.confirmAccepted === "1"
    modal.dataset.confirmAccepted = "0"

    // Сбрасываем inline z-index — для следующего открытия.
    modal.style.zIndex = ""

    // Если ниже остался ОТКРЫТЫЙ модал — Bootstrap снимает body.modal-open
    // (т.к. наш confirm закрылся), нужно вернуть, иначе родитель теряет
    // backdrop-блокировку скролла.
    if (document.querySelectorAll(".modal.show").length > 0) {
      document.body.classList.add("modal-open")
    }

    if (activeResolver) {
      activeResolver(accepted)
      activeResolver = null
    }
  })

  modal.querySelector("[data-confirm-action]")?.addEventListener("click", () => {
    modal.dataset.confirmAccepted = "1"
    window.bootstrap?.Modal.getInstance(modal)?.hide()
  })
  modal.querySelector("[data-confirm-cancel]")?.addEventListener("click", () => {
    modal.dataset.confirmAccepted = "0"
  })
}

document.addEventListener("DOMContentLoaded", bindModalHandlers)
document.addEventListener("turbo:load",       bindModalHandlers)

window.appConfirm = appConfirm

// Перехватываем Turbo confirm — теперь все data-turbo-confirm идут через нашу модалку.
// Используем Turbo.config.forms.confirm (Turbo 8+); fallback на setConfirmMethod
// для старых версий.
if (Turbo.config?.forms) {
  Turbo.config.forms.confirm = (message) => appConfirm(message)
} else if (typeof Turbo.setConfirmMethod === "function") {
  Turbo.setConfirmMethod((message) => appConfirm(message))
}
