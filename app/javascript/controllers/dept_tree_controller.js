import { Controller } from "@hotwired/stimulus"

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content || ""
}

export default class extends Controller {
  static targets = ["node", "children"]
  static values  = {
    storageKey: String,
    expanded:   Array,
    saveDelay:  { type: Number, default: 320 }
  }

  connect() {
    this.expandedSet = new Set((this.expandedValue || []).map(Number))
    this._saveTimer = null
    console.log("[dept-tree] connected; storageKey=", this.storageKeyValue,
                "expanded ids:", Array.from(this.expandedSet),
                "children targets:", this.childrenTargets.length)
  }

  toggle(event) {
    event.preventDefault()
    const id = Number(event.params.id)
    const btn = event.currentTarget
    const children = this._childrenFor(id)
    console.log("[dept-tree] toggle id=", id, "children found?", !!children)
    if (!children) return

    const open = !this.expandedSet.has(id)
    children.classList.toggle("is-collapsed", !open)
    btn.classList.toggle("is-expanded", open)
    btn.setAttribute("aria-expanded", open ? "true" : "false")

    open ? this.expandedSet.add(id) : this.expandedSet.delete(id)
    this._scheduleSave()
  }

  expandAll(event) {
    event?.preventDefault()
    this.childrenTargets.forEach(ul => {
      const id = Number(ul.dataset.deptId)
      ul.classList.remove("is-collapsed")
      this.expandedSet.add(id)
    })
    this.element.querySelectorAll(".dept-tree__toggle").forEach(b => {
      b.classList.add("is-expanded"); b.setAttribute("aria-expanded", "true")
    })
    this._scheduleSave()
  }

  collapseAll(event) {
    event?.preventDefault()
    this.childrenTargets.forEach(ul => ul.classList.add("is-collapsed"))
    this.element.querySelectorAll(".dept-tree__toggle").forEach(b => {
      b.classList.remove("is-expanded"); b.setAttribute("aria-expanded", "false")
    })
    this.expandedSet.clear()
    this._scheduleSave()
  }

  _childrenFor(id) {
    return this.childrenTargets.find(ul => Number(ul.dataset.deptId) === id)
  }

  _scheduleSave() {
    clearTimeout(this._saveTimer)
    this._saveTimer = setTimeout(() => this._save(), this.saveDelayValue)
  }

  _save() {
    const ids = Array.from(this.expandedSet)
    const url = `/grid_preferences/${encodeURIComponent(this.storageKeyValue)}/expanded`
    console.log("[dept-tree] PUT", url, "ids=", ids)
    fetch(url, {
      method: "PUT",
      credentials: "same-origin",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken(), Accept: "application/json" },
      body: JSON.stringify({ data: { ids: ids } })
    })
      .then(r => console.log("[dept-tree] save →", r.status))
      .catch(e => console.error("[dept-tree] save error", e))
  }
}
