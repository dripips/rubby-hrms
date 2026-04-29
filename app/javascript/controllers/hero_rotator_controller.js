import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide"]
  static values  = { interval: { type: Number, default: 4200 } }

  connect() {
    if (this.slideTargets.length === 0) return
    this.dots = this.element.parentElement?.querySelectorAll(".auth-hero__dot") || []

    this.index = this.slideTargets.findIndex(el => el.classList.contains("is-active"))
    if (this.index === -1) {
      this.index = 0
      this.slideTargets[0].classList.add("is-active")
    }
    if (this.slideTargets.length > 1) {
      this.timer = setInterval(() => this.next(), this.intervalValue)
    }
  }

  disconnect() {
    clearInterval(this.timer)
  }

  next() {
    const current = this.slideTargets[this.index]
    current.classList.remove("is-active")
    current.classList.add("is-leaving")
    setTimeout(() => current.classList.remove("is-leaving"), 700)

    this.index = (this.index + 1) % this.slideTargets.length
    this.slideTargets[this.index].classList.add("is-active")

    this.dots.forEach((dot, i) => dot.classList.toggle("is-active", i === this.index))
  }
}
