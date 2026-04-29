import { Controller } from "@hotwired/stimulus"

// Manages the drag-orderable approval chain editor in the leave-rule modal.
// - addRole / addUser append a new step row
// - drag-and-drop reorders the visible row, hidden inputs follow
// - toggleAuto hides/shows the chain block when "auto-approve" is checked
export default class extends Controller {
  static targets = ["list", "chainBlock", "userPicker", "autoCheckbox"]

  toggleAuto() {
    if (!this.hasChainBlockTarget || !this.hasAutoCheckboxTarget) return
    this.chainBlockTarget.style.display = this.autoCheckboxTarget.checked ? "none" : ""
  }

  addRole(event) {
    const role  = event.currentTarget.dataset.ruleChainRoleParam
    const label = event.currentTarget.dataset.ruleChainLabelParam
    if (!role) return
    this.appendStep("role", role, label, "info")
  }

  addUser(event) {
    const select = event.currentTarget
    const id     = select.value
    if (!id) return
    const label  = select.options[select.selectedIndex].dataset.label || `User #${id}`
    this.appendStep("user", id, label, "purple")
    select.value = ""
  }

  appendStep(kind, value, label, tone) {
    const idx  = this.listTarget.querySelectorAll("[data-rule-chain-target='step']").length + 1
    const html = `
      <div class="rule-chain__item" data-rule-chain-target="step" draggable="true"
           data-action="dragstart->rule-chain#dragStart dragover->rule-chain#dragOver drop->rule-chain#drop">
        <span class="rule-chain__handle">⋮⋮</span>
        <span class="rule-chain__index">${idx}</span>
        <span class="pill pill--${tone}">${this.escape(label)}</span>
        <input type="hidden" name="leave_approval_rule[chain_steps][]" value="${kind}:${this.escape(value)}">
        <button type="button" class="btn-close ms-auto" aria-label="remove" data-action="click->rule-chain#remove"></button>
      </div>`
    this.listTarget.insertAdjacentHTML("beforeend", html)
  }

  remove(event) {
    event.currentTarget.closest("[data-rule-chain-target='step']").remove()
    this.renumber()
  }

  dragStart(event) {
    this._dragging = event.currentTarget
    event.dataTransfer.effectAllowed = "move"
  }

  dragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
  }

  drop(event) {
    event.preventDefault()
    const target = event.currentTarget
    if (!this._dragging || this._dragging === target) return
    const rect = target.getBoundingClientRect()
    const after = (event.clientY - rect.top) > rect.height / 2
    target.parentNode.insertBefore(this._dragging, after ? target.nextSibling : target)
    this._dragging = null
    this.renumber()
  }

  renumber() {
    this.listTarget.querySelectorAll("[data-rule-chain-target='step']").forEach((el, i) => {
      const idxSpan = el.querySelector(".rule-chain__index")
      if (idxSpan) idxSpan.textContent = (i + 1).toString()
    })
  }

  escape(s) {
    return String(s).replace(/[&<>"']/g, c => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" }[c]))
  }
}
