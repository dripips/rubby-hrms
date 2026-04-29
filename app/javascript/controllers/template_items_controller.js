import { Controller } from "@hotwired/stimulus"

// Управляет списком задач шаблона процесса. На submit формы собирает все
// карточки в JSON и кладёт в hidden field `process_template[items_json]`.
//
// HTML каркас:
//   <form data-controller="template-items" data-action="submit->template-items#serialize">
//     <ul data-template-items-target="list">…items rendered server-side…</ul>
//     <template data-template-items-target="template"><li class="template-item">…</li></template>
//     <input type="hidden" name="process_template[items_json]" data-template-items-target="payload">
//     <button type="button" data-action="click->template-items#add">+ Добавить</button>
//   </form>
export default class extends Controller {
  static targets = ["list", "template", "payload"]

  connect() {
    this._renumber()
  }

  add() {
    const tpl = this.templateTarget.content.firstElementChild.cloneNode(true)
    this.listTarget.appendChild(tpl)
    this._renumber()
  }

  remove(event) {
    event.currentTarget.closest(".template-item").remove()
    this._renumber()
  }

  serialize() {
    const items = []
    this.listTarget.querySelectorAll(".template-item").forEach((row, idx) => {
      const title = row.querySelector("[data-field='title']")?.value?.trim()
      if (!title) return
      items.push({
        title,
        kind:            row.querySelector("[data-field='kind']")?.value || "general",
        description:     row.querySelector("[data-field='description']")?.value?.trim() || "",
        due_offset_days: parseInt(row.querySelector("[data-field='due_offset_days']")?.value || "0", 10),
        position:        idx
      })
    })
    this.payloadTarget.value = JSON.stringify(items)
  }

  _renumber() {
    this.listTarget.querySelectorAll(".template-item").forEach((row, i) => {
      const idx = row.querySelector(".template-item__index")
      if (idx) idx.textContent = (i + 1).toString()
    })
  }
}
