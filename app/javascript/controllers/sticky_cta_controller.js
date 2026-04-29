import { Controller } from "@hotwired/stimulus"

// Показывает плавающую CTA (например "Откликнуться") пока target-форма
// не попала в viewport. Когда форма видна — CTA скрывается, чтобы не
// дублировать кнопку.
//
// <a class="careers-sticky-cta" data-controller="sticky-cta"
//    data-sticky-cta-target-id-value="application-form">…</a>
export default class extends Controller {
  static values = { targetId: String }

  connect() {
    const target = document.getElementById(this.targetIdValue)
    if (!target) {
      // Нет target — оставляем кнопку видимой всегда
      this.element.classList.add("is-visible")
      return
    }

    // Изначально показываем (форма ниже, не в viewport)
    requestAnimationFrame(() => this.element.classList.add("is-visible"))

    this._observer = new IntersectionObserver((entries) => {
      const entry = entries[0]
      if (entry.isIntersecting) {
        this.element.classList.remove("is-visible")
      } else {
        this.element.classList.add("is-visible")
      }
    }, { threshold: 0.15 })

    this._observer.observe(target)
  }

  disconnect() {
    this._observer?.disconnect()
  }
}
