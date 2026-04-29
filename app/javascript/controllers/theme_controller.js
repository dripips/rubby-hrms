import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option", "indicator"]

  connect() {
    this.mode = this.readCookie() || "auto"
    this.apply()
    this.refreshUi()
  }

  set(event) {
    this.mode = event.params.mode
    this.writeCookie()
    this.apply()
    this.refreshUi()
  }

  apply() {
    const html = document.documentElement
    const resolved = this.mode === "auto"
      ? (window.matchMedia?.("(prefers-color-scheme: dark)").matches ? "dark" : "light")
      : this.mode
    if (this.mode === "auto") {
      html.removeAttribute("data-theme")
    } else {
      html.setAttribute("data-theme", this.mode)
    }
    // Sync Bootstrap 5.3 theme so form controls / dropdowns adapt automatically.
    html.setAttribute("data-bs-theme", resolved)
  }

  refreshUi() {
    this.optionTargets.forEach(el => {
      el.classList.toggle("active", el.dataset.themeModeParam === this.mode)
    })
    if (this.hasIndicatorTarget) {
      const symbol = this.mode === "light" ? "sun" : this.mode === "dark" ? "moon" : "auto"
      this.indicatorTarget.dataset.icon = symbol
    }
  }

  readCookie() {
    const m = document.cookie.match(/(?:^|;\s*)theme=([^;]+)/)
    return m ? decodeURIComponent(m[1]) : null
  }

  writeCookie() {
    document.cookie = `theme=${this.mode}; path=/; max-age=31536000; samesite=lax`
  }
}
