import { Controller } from "@hotwired/stimulus"

// Управляет UX-частью выбора AI-провайдера в Settings → AI.
// Контроллер сидит на ОБЁРТКЕ формы (не на каждом радио), чтобы видеть все
// targets разом.
//
// Действия:
// - switch(event) — клик по чипу провайдера. Берёт url+provider из data-params
//   и: подставляет URL в endpoint-input, переключает rich-cards (OpenAI) ↔
//   custom (free-form input + пресеты под выбранного провайдера), дисейблит
//   инпуты в неактивном блоке чтобы не было дубликатной submit-name'ы.
// - pickModel(event) — клик по чипу-модели: пишет имя в кастомный text input.
export default class extends Controller {
  static targets = ["openaiBlock", "customBlock", "customModelInput", "presetGroup"]

  switch(event) {
    const url      = event.params?.url      || ""
    const provider = event.params?.provider || "openai"

    const urlInput = document.getElementById("ai_api_base_url")
    if (urlInput && url) urlInput.value = url

    const isOpenai = provider === "openai"
    this._toggleBlock(this.openaiBlockTarget, isOpenai)
    this._toggleBlock(this.customBlockTarget, !isOpenai)
    this._setBlockEnabled(this.openaiBlockTarget, isOpenai)
    this._setBlockEnabled(this.customBlockTarget, !isOpenai)

    // Преcеты моделей разных провайдеров: показываем только активного.
    this.presetGroupTargets.forEach((group) => {
      const matches = group.dataset.provider === provider
      group.classList.toggle("d-none", !matches)
    })
  }

  pickModel(event) {
    const name = event.params?.model
    if (!name || !this.hasCustomModelInputTarget) return
    this.customModelInputTarget.value = name
    this.customModelInputTarget.focus()
  }

  _toggleBlock(el, visible) {
    if (!el) return
    el.classList.toggle("d-none", !visible)
  }

  _setBlockEnabled(el, enabled) {
    if (!el) return
    el.querySelectorAll("input, select, textarea").forEach((i) => {
      i.disabled = !enabled
    })
  }
}
