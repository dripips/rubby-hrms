import { Controller } from "@hotwired/stimulus"

// Drag-and-drop reorder без библиотек. Стимулус-контроллер на UL,
// items имеют draggable="true". На submit формы собираем актуальный порядок
// и список скрытых в hidden inputs.
export default class extends Controller {
  static targets = ["list", "form", "hiddenContainer"]

  connect() {
    this._bindDragHandlers()
  }

  _bindDragHandlers() {
    if (!this.hasListTarget) return
    let dragging = null

    this.listTarget.addEventListener("dragstart", (e) => {
      const item = e.target.closest("[data-widget-key]")
      if (!item) return
      dragging = item
      item.classList.add("is-dragging")
      e.dataTransfer.effectAllowed = "move"
      // Firefox требует не-пустого dataTransfer
      e.dataTransfer.setData("text/plain", item.dataset.widgetKey || "")
    })

    this.listTarget.addEventListener("dragover", (e) => {
      e.preventDefault()
      if (!dragging) return
      const target = e.target.closest("[data-widget-key]")
      if (!target || target === dragging) return

      const rect = target.getBoundingClientRect()
      const before = (e.clientY - rect.top) < (rect.height / 2)
      this.listTarget.insertBefore(dragging, before ? target : target.nextSibling)
    })

    this.listTarget.addEventListener("dragend", () => {
      if (dragging) dragging.classList.remove("is-dragging")
      dragging = null
    })
  }

  // На submit формы — собираем актуальный порядок + скрытые ключи в hidden inputs.
  prepareSubmit(event) {
    if (!this.hasHiddenContainerTarget) return
    this.hiddenContainerTarget.innerHTML = ""

    const items = this.listTarget.querySelectorAll("[data-widget-key]")
    items.forEach((item) => {
      const key = item.dataset.widgetKey
      // order[]
      const orderInput = document.createElement("input")
      orderInput.type = "hidden"
      orderInput.name = "order[]"
      orderInput.value = key
      this.hiddenContainerTarget.appendChild(orderInput)

      // hidden[] — для тех у кого checkbox unchecked
      const cb = item.querySelector('input[type="checkbox"][data-customize="visible"]')
      if (cb && !cb.checked) {
        const h = document.createElement("input")
        h.type = "hidden"
        h.name = "hidden[]"
        h.value = key
        this.hiddenContainerTarget.appendChild(h)
      }
    })
  }
}
