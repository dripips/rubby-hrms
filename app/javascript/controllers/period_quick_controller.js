import { Controller } from "@hotwired/stimulus"

// Quick-fills period_start / period_end inside the same form when a preset
// button is clicked. Buttons carry data-period-from / data-period-to (ISO).
export default class extends Controller {
  apply(event) {
    const btn  = event.currentTarget
    const form = btn.closest("form")
    if (!form) return

    const from = btn.dataset.periodFrom
    const to   = btn.dataset.periodTo
    const fromInput = form.querySelector('input[type="date"][name*="period_start"]')
    const toInput   = form.querySelector('input[type="date"][name*="period_end"]')

    if (fromInput && from) fromInput.value = from
    if (toInput   && to)   toInput.value   = to
  }
}
