import "@hotwired/turbo-rails"
import "turbo_confirm"
import "controllers"

// Bootstrap (UMD bundle with Popper) is loaded via a <script> tag in the layout
// and exposes itself as `window.bootstrap`. Wait for it, then auto-init widgets.
function initBootstrapWidgets(root = document) {
  if (!window.bootstrap) return
  root.querySelectorAll('[data-bs-toggle="dropdown"]').forEach(el => window.bootstrap.Dropdown.getOrCreateInstance(el))
  root.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(el => window.bootstrap.Tooltip.getOrCreateInstance(el))
  root.querySelectorAll('[data-bs-toggle="popover"]').forEach(el => window.bootstrap.Popover.getOrCreateInstance(el))
  root.querySelectorAll('[data-bs-toggle="modal"]').forEach(el => window.bootstrap.Modal.getOrCreateInstance(el))
  root.querySelectorAll('[data-bs-toggle="offcanvas"]').forEach(el => window.bootstrap.Offcanvas.getOrCreateInstance(el))
}

document.addEventListener("turbo:load", () => initBootstrapWidgets())
document.addEventListener("turbo:frame-load", e => initBootstrapWidgets(e.target))
document.addEventListener("DOMContentLoaded", () => initBootstrapWidgets())

// Auto-enhance: все native <select> с классом form-select получают apple-select
// Stimulus-контроллер. Исключения: multiple-select, уже-настроенные (data-controller)
// и select'ы внутри filter-chip (там уже стоит data-controller на wrapper).
function autoApplyAppleSelect(root = document) {
  const selects = root.querySelectorAll(
    "select.form-select:not([multiple]):not([data-controller]):not(.apple-select__source)"
  )
  selects.forEach(sel => {
    if (sel.closest("[data-controller~='apple-select']")) return
    sel.setAttribute("data-controller", "apple-select")
  })
}

// Auto-enhance: <input type="date|datetime-local"> → apple-date-picker
function autoApplyAppleDatePicker(root = document) {
  const inputs = root.querySelectorAll(
    'input[type="date"]:not([data-controller]):not(.apple-date-picker__source), ' +
    'input[type="datetime-local"]:not([data-controller]):not(.apple-date-picker__source)'
  )
  inputs.forEach(inp => {
    if (inp.closest("[data-controller~='apple-date-picker']")) return
    inp.setAttribute("data-controller", "apple-date-picker")
  })
}

document.addEventListener("turbo:load", () => {
  autoApplyAppleSelect()
  autoApplyAppleDatePicker()
})
document.addEventListener("turbo:frame-load", e => {
  autoApplyAppleSelect(e.target)
  autoApplyAppleDatePicker(e.target)
})
document.addEventListener("DOMContentLoaded", () => {
  autoApplyAppleSelect()
  autoApplyAppleDatePicker()
})

// Bootstrap 5.3.3 bug: aria-hidden остаётся на закрытой модалке, пока внутри
// есть focused элемент (.btn-close). Сбрасываем фокус заранее.
document.addEventListener("hide.bs.modal", e => {
  if (e.target.contains(document.activeElement)) document.activeElement.blur()
})
