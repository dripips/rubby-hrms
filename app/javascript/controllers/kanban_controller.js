import { Controller } from "@hotwired/stimulus"

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content || ""
}

export default class extends Controller {
  static targets = ["column", "count"]

  connect() {
    if (typeof Sortable === "undefined") {
      setTimeout(() => this.connect(), 80)
      return
    }

    console.log("[kanban] connect, total .kanban__card in DOM:", document.querySelectorAll(".kanban__card").length)

    this.dragMoved = false

    this.sortables = this.columnTargets.map((col) => {
      return new Sortable(col, {
        group: "kanban",
        animation: 180,
        easing: "cubic-bezier(0.32, 0.72, 0, 1)",
        draggable: ".kanban__card",
        ghostClass: "kanban__card--ghost",
        chosenClass: "kanban__card--dragging",
        // НИКАКОГО forceFallback/fallbackOnBody — используем native HTML5 DnD,
        // он корректно убирает оригинал при drop в другой контейнер.
        emptyInsertThreshold: 40,
        invertSwap: true,
        onStart: () => { this.dragMoved = true },
        onEnd:   (evt) => {
          console.log("[kanban] drop:", evt.item.dataset.applicantId, "from", evt.from.dataset.stage, "to", evt.to.dataset.stage)
          this._onDrop(evt)
          setTimeout(() => { this.dragMoved = false }, 50)
        }
      })
    })

    this._refreshCounts()
  }

  // Click-handler заменяет href: только если карточка НЕ была перетянута.
  openCard(event) {
    if (this.dragMoved) { event.preventDefault(); return }
    const card = event.currentTarget
    const href = card.dataset.href
    if (!href) return
    // Открываем в той же вкладке. Для new tab — Ctrl/Cmd+Click.
    if (event.metaKey || event.ctrlKey) window.open(href, "_blank")
    else window.location.href = href
  }

  disconnect() {
    this.sortables?.forEach(s => s.destroy())
  }

  async _onDrop(evt) {
    const card = evt.item
    const newColumn = evt.to
    const oldColumn = evt.from
    if (newColumn === oldColumn && evt.oldIndex === evt.newIndex) return

    const id = card.dataset.applicantId
    const stage = newColumn.dataset.stage
    if (!id || !stage) return

    // Подтверждение для потенциально-разрушительных переходов
    // (отказ, найм, оффер, отзыв) — там может уйти коммуникация кандидату.
    const requiresConfirm = ["rejected", "withdrawn", "offered", "hired"].includes(stage)
    if (requiresConfirm && window.appConfirm) {
      const ok = await window.appConfirm(
        `Точно перевести кандидата на стадию «${newColumn.dataset.stageLabel || stage}»? На этом этапе кандидату может уйти коммуникация.`
      )
      if (!ok) {
        // Откатываем drop — возвращаем карточку в старую колонку.
        oldColumn.insertBefore(card, oldColumn.children[evt.oldIndex] || null)
        this._refreshCounts()
        return
      }
    }

    try {
      const res = await fetch(`/job_applicants/${id}/move_stage`, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken(),
          Accept: "application/json"
        },
        body: JSON.stringify({ stage })
      })
      if (!res.ok) throw new Error("Server returned " + res.status)
      const data = await res.json()
      const daysEl = card.querySelector("[data-days-in-stage]")
      if (daysEl) daysEl.textContent = data.days_in_stage
    } catch (e) {
      // При ошибке — просто перезагружаем страницу, сервер вернёт правильное состояние.
      console.error("[kanban] move failed, reloading", e)
      window.location.reload()
      return
    }
    this._refreshCounts()
  }

  _refreshCounts() {
    this.columnTargets.forEach(col => {
      const stage = col.dataset.stage
      const count = col.querySelectorAll(".kanban__card").length
      const counter = this.element.querySelector(`[data-stage-count="${stage}"]`)
      if (counter) counter.textContent = count
    })
  }
}
