import { Controller } from "@hotwired/stimulus"

// Code-block language tabs.
//   <div data-controller="code-tabs">
//     <div class="code-tabs__nav">
//       <button data-code-tabs-target="tab" data-lang="curl" data-action="click->code-tabs#switch">curl</button>
//       <button data-code-tabs-target="tab" data-lang="js"   data-action="click->code-tabs#switch">JS</button>
//     </div>
//     <pre data-code-tabs-target="block" data-lang="curl">…</pre>
//     <pre data-code-tabs-target="block" data-lang="js">…</pre>
//   </div>
export default class extends Controller {
  static targets = ["tab", "block"]
  static values  = { defaultLang: { type: String, default: "curl" } }

  connect() {
    const initial = this.tabTargets.find(t => t.dataset.lang === this.defaultLangValue) || this.tabTargets[0]
    if (initial) this._activate(initial.dataset.lang)
  }

  switch(event) {
    event.preventDefault()
    const lang = event.currentTarget.dataset.lang
    if (lang) this._activate(lang)
  }

  _activate(lang) {
    this.tabTargets.forEach(t => t.classList.toggle("is-active", t.dataset.lang === lang))
    this.blockTargets.forEach(b => b.classList.toggle("is-active", b.dataset.lang === lang))
  }
}
