import { Controller } from "@hotwired/stimulus"

// Live day counter for the "New leave request" form.
// - Watches from/to date inputs and shows the inclusive day count.
// - Quick-preset buttons set `to = from + N - 1`.
export default class extends Controller {
  static targets = ["from", "to", "counter", "counterValue"]

  connect() { this.recalc() }

  recalc() {
    if (!this.hasFromTarget || !this.hasToTarget) return
    const from = this.fromTarget.value ? new Date(this.fromTarget.value) : null
    const to   = this.toTarget.value   ? new Date(this.toTarget.value)   : null

    if (!from || !to || isNaN(from) || isNaN(to) || to < from) {
      if (this.hasCounterValueTarget) this.counterValueTarget.textContent = "0"
      this.counterTarget?.classList.remove("is-active")
      return
    }

    const days = Math.round((to - from) / (1000 * 60 * 60 * 24)) + 1
    if (this.hasCounterValueTarget) this.counterValueTarget.textContent = days.toString()
    this.counterTarget?.classList.toggle("is-active", days > 0)
  }

  applyPreset(event) {
    const days = parseInt(event.currentTarget.dataset.leaveFormDaysParam, 10)
    if (!days) return

    const fromInput = this.fromTarget
    if (!fromInput.value) {
      const today = new Date()
      fromInput.value = today.toISOString().slice(0, 10)
    }
    const from = new Date(fromInput.value)
    const to   = new Date(from)
    to.setDate(to.getDate() + days - 1)
    this.toTarget.value = to.toISOString().slice(0, 10)
    this.recalc()
  }
}
