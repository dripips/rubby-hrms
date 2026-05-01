import { Controller } from "@hotwired/stimulus"

// Zoom + pan для preview документа на странице review_extracted.
// Поддерживает кнопки +/−/reset, scroll-wheel zoom, drag для перемещения.
export default class extends Controller {
  static targets = ["stage", "subject", "level"]

  connect() {
    this.scale = 1
    this.minScale = 0.5
    this.maxScale = 4
    this.step = 0.25
    this.applyTransform()
    this._bindWheel()
    this._bindDrag()
  }

  zoomIn()  { this._setScale(this.scale + this.step) }
  zoomOut() { this._setScale(this.scale - this.step) }
  reset()   {
    this._setScale(1)
    if (this.hasStageTarget) {
      this.stageTarget.scrollLeft = 0
      this.stageTarget.scrollTop  = 0
    }
  }

  _setScale(next) {
    this.scale = Math.max(this.minScale, Math.min(this.maxScale, next))
    this.applyTransform()
  }

  applyTransform() {
    if (this.hasSubjectTarget) {
      this.subjectTarget.style.transform = `scale(${this.scale})`
      this.subjectTarget.style.transformOrigin = "top left"
    }
    if (this.hasLevelTarget) {
      this.levelTarget.textContent = `${Math.round(this.scale * 100)}%`
    }
  }

  _bindWheel() {
    if (!this.hasStageTarget) return
    this.stageTarget.addEventListener("wheel", (e) => {
      if (!e.ctrlKey && !e.metaKey) return
      e.preventDefault()
      const delta = e.deltaY < 0 ? this.step : -this.step
      this._setScale(this.scale + delta)
    }, { passive: false })
  }

  _bindDrag() {
    if (!this.hasStageTarget) return
    let dragging = false
    let startX = 0, startY = 0, scrollLeft = 0, scrollTop = 0

    this.stageTarget.addEventListener("mousedown", (e) => {
      // не мешаем кликам по кнопкам/ссылкам
      if (e.target.closest("a, button")) return
      dragging = true
      startX = e.pageX
      startY = e.pageY
      scrollLeft = this.stageTarget.scrollLeft
      scrollTop  = this.stageTarget.scrollTop
      this.stageTarget.style.cursor = "grabbing"
      e.preventDefault()
    })

    const stop = () => {
      dragging = false
      this.stageTarget.style.cursor = ""
    }
    document.addEventListener("mouseup", stop)
    this.stageTarget.addEventListener("mouseleave", stop)

    this.stageTarget.addEventListener("mousemove", (e) => {
      if (!dragging) return
      this.stageTarget.scrollLeft = scrollLeft - (e.pageX - startX)
      this.stageTarget.scrollTop  = scrollTop  - (e.pageY - startY)
    })
  }
}
