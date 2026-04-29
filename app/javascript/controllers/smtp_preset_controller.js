import { Controller } from "@hotwired/stimulus"

// Авто-заполнение SMTP-формы по нажатию на пресет.
// Использование:
//   <div data-controller="smtp-preset">
//     <button type="button" data-preset='{"host":"smtp.gmail.com","port":587,"tls":true,"auth":"plain"}'
//             data-action="click->smtp-preset#apply">Gmail</button>
//     <input name="app_setting[data][host]"> ...
//   </div>
export default class extends Controller {
  apply(event) {
    event.preventDefault()
    const data = JSON.parse(event.currentTarget.dataset.preset || "{}")

    const setField = (name, value) => {
      const el = this.element.querySelector(`[name="app_setting[data][${name}]"]`)
      if (!el) return
      if (el.type === "checkbox") {
        el.checked = !!value
      } else {
        el.value = value
      }
    }

    if (data.host !== undefined) setField("host", data.host)
    if (data.port !== undefined) setField("port", data.port)
    if (data.auth !== undefined) setField("authentication", data.auth)
    if (data.tls  !== undefined) setField("tls", data.tls)

    // Лёгкая визуальная подсветка: помечаем активную кнопку
    this.element.querySelectorAll("[data-preset]").forEach(b => b.classList.remove("is-active"))
    event.currentTarget.classList.add("is-active")
  }
}
