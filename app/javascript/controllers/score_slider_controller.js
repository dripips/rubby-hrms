import { Controller } from "@hotwired/stimulus"

// Live-updates the displayed % value next to the score range slider.
export default class extends Controller {
  static targets = ["slider", "value"]

  connect() { this.update() }

  update() {
    if (this.hasSliderTarget && this.hasValueTarget) {
      this.valueTarget.textContent = `${this.sliderTarget.value}%`
    }
  }
}
