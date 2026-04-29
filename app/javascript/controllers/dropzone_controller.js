import { Controller } from "@hotwired/stimulus"

// Apple-стайл drag & drop zone для file input.
// Подхватывает drop'нутые файлы, показывает preview (для image)
// и стилизует zone в момент dragover.
//
// Markup:
//   <label class="dropzone" data-controller="dropzone" data-dropzone-target="zone">
//     <input type="file" data-dropzone-target="input" data-action="change->dropzone#changed">
//     <div class="dropzone__icon">…svg…</div>
//     <div class="dropzone__text">
//       <strong data-dropzone-target="title">Drop or click</strong>
//       <span data-dropzone-target="hint">PNG, SVG · до 2MB</span>
//     </div>
//   </label>
export default class extends Controller {
  static targets = ["zone", "input", "title", "hint", "preview"]

  connect() {
    const root = this.hasZoneTarget ? this.zoneTarget : this.element
    this._root = root

    this._onDragEnter = this._onDragEnter.bind(this)
    this._onDragOver  = this._onDragOver.bind(this)
    this._onDragLeave = this._onDragLeave.bind(this)
    this._onDrop      = this._onDrop.bind(this)

    root.addEventListener("dragenter", this._onDragEnter)
    root.addEventListener("dragover",  this._onDragOver)
    root.addEventListener("dragleave", this._onDragLeave)
    root.addEventListener("drop",      this._onDrop)
  }

  disconnect() {
    if (!this._root) return
    this._root.removeEventListener("dragenter", this._onDragEnter)
    this._root.removeEventListener("dragover",  this._onDragOver)
    this._root.removeEventListener("dragleave", this._onDragLeave)
    this._root.removeEventListener("drop",      this._onDrop)
  }

  _onDragEnter(e) { e.preventDefault(); this._dragCount = (this._dragCount || 0) + 1; this._root.classList.add("is-drag") }
  _onDragOver(e)  { e.preventDefault(); e.dataTransfer.dropEffect = "copy" }
  _onDragLeave(e) {
    e.preventDefault()
    this._dragCount = Math.max(0, (this._dragCount || 0) - 1)
    if (this._dragCount === 0) this._root.classList.remove("is-drag")
  }
  _onDrop(e) {
    e.preventDefault()
    this._dragCount = 0
    this._root.classList.remove("is-drag")

    const files = e.dataTransfer?.files
    if (!files || !files.length) return

    if (this.hasInputTarget) {
      // Используем DataTransfer чтобы корректно подставить File-list
      const dt = new DataTransfer()
      const isMulti = this.inputTarget.multiple
      const list = isMulti ? Array.from(files) : [files[0]]
      list.forEach(f => dt.items.add(f))
      this.inputTarget.files = dt.files
      this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }

  changed(event) {
    const files = event.target.files
    if (!files || !files.length) return

    const list = Array.from(files)
    if (this.hasTitleTarget) {
      this.titleTarget.textContent = list.length === 1
        ? list[0].name
        : `${list.length} файла выбрано`
    }
    if (this.hasHintTarget) {
      const totalKB = list.reduce((s, f) => s + f.size, 0) / 1024
      this.hintTarget.textContent = totalKB > 1024
        ? `${(totalKB / 1024).toFixed(2)} MB · готово к отправке`
        : `${totalKB.toFixed(0)} KB · готово к отправке`
    }
    this._root.classList.add("is-filled")
    this._renderPreview(list)
  }

  // Маленькие chip'ы под dropzone — имя + размер + ✕ remove
  _renderPreview(files) {
    let preview = this._root.parentElement.querySelector(".dropzone-files")
    if (!preview) {
      preview = document.createElement("div")
      preview.className = "dropzone-files"
      this._root.parentElement.insertBefore(preview, this._root.nextSibling)
    }
    preview.innerHTML = ""
    files.forEach((file, idx) => {
      const chip = document.createElement("div")
      chip.className = "dropzone-file"
      const sizeKB = file.size / 1024
      const sizeStr = sizeKB > 1024 ? `${(sizeKB / 1024).toFixed(2)} MB` : `${sizeKB.toFixed(0)} KB`
      chip.innerHTML = `
        <svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><path d="M9 1.5H4a1 1 0 0 0-1 1V14a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1V5.5L9 1.5Z"/><path d="M9 1.5V5.5h4"/></svg>
        <span class="dropzone-file__name">${this._escape(file.name)}</span>
        <span class="dropzone-file__size">${sizeStr}</span>
        <button type="button" class="dropzone-file__remove" aria-label="remove" data-idx="${idx}">✕</button>
      `
      preview.appendChild(chip)
    })

    preview.querySelectorAll(".dropzone-file__remove").forEach(btn => {
      btn.addEventListener("click", (e) => {
        e.preventDefault()
        e.stopPropagation()
        this._removeFile(parseInt(btn.dataset.idx, 10))
      })
    })
  }

  _removeFile(idx) {
    if (!this.hasInputTarget) return
    const remaining = Array.from(this.inputTarget.files).filter((_, i) => i !== idx)
    const dt = new DataTransfer()
    remaining.forEach(f => dt.items.add(f))
    this.inputTarget.files = dt.files
    if (remaining.length === 0) {
      this._root.classList.remove("is-filled")
      const preview = this._root.parentElement.querySelector(".dropzone-files")
      preview?.remove()
      // Reset title/hint
      if (this.hasTitleTarget) this.titleTarget.textContent = this._origTitle()
      if (this.hasHintTarget)  this.hintTarget.textContent  = this._origHint()
    } else {
      this._renderPreview(remaining)
      if (this.hasTitleTarget) this.titleTarget.textContent = `${remaining.length} файла выбрано`
    }
  }

  _origTitle() { return this._cachedTitle ||= this.hasTitleTarget ? this.titleTarget.dataset.original || this.titleTarget.textContent : "" }
  _origHint()  { return this._cachedHint  ||= this.hasHintTarget  ? this.hintTarget.dataset.original  || this.hintTarget.textContent  : "" }

  _escape(s) {
    const div = document.createElement("div")
    div.textContent = s
    return div.innerHTML
  }
}
