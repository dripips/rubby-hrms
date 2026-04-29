import { Controller } from "@hotwired/stimulus"

// Apple-style FullCalendar обёртка:
//  • teleport-to-body popover (фикс stacking-context)
//  • viewport-fixed позиционирование от cursor-coords (надёжно при scroll/transform-родителях)
//  • кастомный chip-renderer (плотный week view)
//  • pill-chip фильтры с синком label при выборе
//  • сортируемая agenda-таблица
export default class extends Controller {
  static values  = { eventsUrl: String, locale: String }
  static targets = [
    "calendar",
    "interviewerFilter", "kindFilter", "stateFilter",
    "interviewerLabel", "kindLabel", "stateLabel",
    "popover", "popoverAvatar", "popoverCandidate", "popoverOpening",
    "popoverState", "popoverKind", "popoverWhen",
    "popoverInterviewer", "popoverLocation", "popoverLocationLabel",
    "popoverScore", "popoverScoreLabel",
    "agenda"
  ]

  connect() {
    this._cacheAndTeleportPopover()
    this._syncChipLabels()
    this._bootCalendar()
    this._sortDir = { when: "asc" }
    this._currentSort = "when"
  }

  disconnect() {
    this._calendar?.destroy()
    this._popover?.root?.remove()
    this._popover = null
  }

  // ─── Popover teleport + ref-cache ──────────────────────────────────────
  // ВАЖНО: после teleport-а в body Stimulus-targets ломаются, потому что
  // ищут элементы только внутри scope контроллера. Кэшируем все ссылки
  // ДО teleport'а и используем кэш во всех методах.
  _cacheAndTeleportPopover() {
    if (!this.hasPopoverTarget) return

    const root = this.popoverTarget
    this._popover = {
      root,
      avatar:        this.hasPopoverAvatarTarget        ? this.popoverAvatarTarget        : null,
      candidate:     this.hasPopoverCandidateTarget     ? this.popoverCandidateTarget     : null,
      opening:       this.hasPopoverOpeningTarget       ? this.popoverOpeningTarget       : null,
      state:         this.hasPopoverStateTarget         ? this.popoverStateTarget         : null,
      kind:          this.hasPopoverKindTarget          ? this.popoverKindTarget          : null,
      when:          this.hasPopoverWhenTarget          ? this.popoverWhenTarget          : null,
      interviewer:   this.hasPopoverInterviewerTarget   ? this.popoverInterviewerTarget   : null,
      location:      this.hasPopoverLocationTarget      ? this.popoverLocationTarget      : null,
      locationLabel: this.hasPopoverLocationLabelTarget ? this.popoverLocationLabelTarget : null,
      score:         this.hasPopoverScoreTarget         ? this.popoverScoreTarget         : null,
      scoreLabel:    this.hasPopoverScoreLabelTarget    ? this.popoverScoreLabelTarget    : null
    }

    if (root.parentElement !== document.body) {
      document.body.appendChild(root)
    }
  }

  // ─── FullCalendar boot ─────────────────────────────────────────────────
  _bootCalendar() {
    if (!window.FullCalendar) {
      setTimeout(() => this._bootCalendar(), 80)
      return
    }
    if (!this.hasCalendarTarget) return

    const locale = this.localeValue === "ru" ? "ru" : "en"

    this._calendar = new FullCalendar.Calendar(this.calendarTarget, {
      initialView: "timeGridWeek",
      locale,
      headerToolbar: {
        left:   "prev,next today",
        center: "title",
        right:  "dayGridMonth,timeGridWeek,timeGridDay,listWeek"
      },
      buttonText: locale === "ru" ? {
        today: "Сегодня", month: "Месяц", week: "Неделя", day: "День", list: "Список"
      } : undefined,
      slotMinTime:       "08:00:00",
      slotMaxTime:       "22:00:00",
      slotDuration:      "00:30:00",
      slotLabelInterval: "01:00",
      slotLabelFormat:   { hour: "numeric", minute: "2-digit", hour12: false },
      expandRows:        true,
      eventMinHeight:    32,
      dayMaxEvents:      3,
      slotEventOverlap:  false,
      eventMaxStack:     2,
      moreLinkClick:     "popover",
      moreLinkText:      (n) => `+${n}`,
      nowIndicator:      true,
      firstDay:          1,
      height:            "auto",

      events:        (info, success, failure) => this._fetchEvents(info, success, failure),
      eventContent:  (arg) => this._renderEventChip(arg),
      eventMouseEnter: (info) => this._showPopover(info.jsEvent, info.event),
      eventMouseLeave: ()     => this._hidePopover(),

      // Клик на дату в month-view → переход в day-view с этим числом.
      // В week-view клик на ячейку времени тоже открывает day-view (точечный фокус).
      dateClick: (info) => {
        const view = info.view?.type
        if (view === "dayGridMonth" || view === "timeGridWeek") {
          this._calendar.changeView("timeGridDay", info.date)
        }
      }
    })

    this._calendar.render()
  }

  // ─── Chip renderer (Apple-style плотный event) ─────────────────────────
  _renderEventChip(arg) {
    const p = arg.event.extendedProps || {}
    const candidate = p.candidate || arg.event.title || ""

    const root = document.createElement("div")
    root.className = "fc-chip"
    if (p.tint_color) root.style.setProperty("--fc-event-bg-tint", p.tint_color)
    if (arg.event.backgroundColor) root.style.setProperty("--fc-event-fg", arg.event.backgroundColor)

    const dot = document.createElement("span")
    dot.className = "fc-chip__dot"

    const time = document.createElement("span")
    time.className = "fc-chip__time"
    time.textContent = arg.timeText || ""

    const name = document.createElement("span")
    name.className = "fc-chip__name"
    name.textContent = candidate

    root.appendChild(dot)
    if (arg.timeText) root.appendChild(time)
    root.appendChild(name)

    return { domNodes: [root] }
  }

  // ─── Filters ────────────────────────────────────────────────────────────
  refetch() {
    this._syncChipLabels()
    this._calendar?.refetchEvents()
  }

  resetFilters() {
    [this.hasInterviewerFilterTarget && this.interviewerFilterTarget,
     this.hasKindFilterTarget        && this.kindFilterTarget,
     this.hasStateFilterTarget       && this.stateFilterTarget]
      .filter(Boolean)
      .forEach(sel => {
        sel.value = ""
        sel.dispatchEvent(new Event("change", { bubbles: true }))
      })
    // refetch уже сработает через change-handler, но на всякий случай
    this.refetch()
  }

  _syncChipLabels() {
    this._writeLabel("interviewer")
    this._writeLabel("kind")
    this._writeLabel("state")
  }

  _writeLabel(key) {
    const cap = key[0].toUpperCase() + key.slice(1)
    if (!this[`has${cap}FilterTarget`]) return
    if (!this[`has${cap}LabelTarget`])  return
    const select = this[`${key}FilterTarget`]
    const label  = this[`${key}LabelTarget`]
    const opt    = select.options[select.selectedIndex]
    label.textContent = opt ? opt.textContent : ""
  }

  _fetchEvents(info, success, failure) {
    const params = new URLSearchParams({ start: info.startStr, end: info.endStr })
    if (this.hasInterviewerFilterTarget && this.interviewerFilterTarget.value) {
      params.set("interviewer_id", this.interviewerFilterTarget.value)
    }
    if (this.hasKindFilterTarget && this.kindFilterTarget.value) {
      params.set("kind", this.kindFilterTarget.value)
    }
    if (this.hasStateFilterTarget && this.stateFilterTarget.value) {
      params.set("state", this.stateFilterTarget.value)
    }

    fetch(`${this.eventsUrlValue}?${params}`, {
      headers: { Accept: "application/json" },
      credentials: "same-origin"
    })
      .then(r => r.json())
      .then(success)
      .catch(failure)
  }

  // ─── Popover (cursor-anchored, viewport-fixed, кэшированные refs) ──────
  _showPopover(jsEvent, event) {
    const pop = this._popover
    if (!pop) return
    const p = event.extendedProps || {}

    if (pop.avatar) {
      if (p.avatar_url) {
        pop.avatar.style.backgroundImage = `url(${p.avatar_url})`
        pop.avatar.textContent = ""
        pop.avatar.classList.add("event-popover__avatar--photo")
      } else {
        pop.avatar.style.backgroundImage = ""
        pop.avatar.textContent = p.candidate_initials || "??"
        pop.avatar.classList.remove("event-popover__avatar--photo")
      }
    }

    if (pop.candidate) pop.candidate.textContent = p.candidate || ""
    if (pop.opening) {
      pop.opening.textContent = p.opening || ""
      pop.opening.style.display = p.opening ? "" : "none"
    }
    if (pop.state) {
      pop.state.textContent = p.state_label || ""
      pop.state.className   = "pill pill--" + this._stateTone(p.state)
    }
    if (pop.kind)        pop.kind.textContent        = p.kind_label || p.kind || "—"
    if (pop.when)        pop.when.textContent        = this._formatWhen(event.start, p.duration)
    if (pop.interviewer) pop.interviewer.textContent = p.interviewer || "—"

    this._setOptional(pop.location, pop.locationLabel, p.location)
    this._setOptional(
      pop.score, pop.scoreLabel,
      p.score ? `${p.score}/100${p.recommendation ? " · " + p.recommendation : ""}` : null
    )

    // Отменяем предыдущий hide-timer чтобы при быстром переходе между event'ами
    // popover не флипал в hidden=true посреди показа.
    if (this._hideTimer) {
      clearTimeout(this._hideTimer)
      this._hideTimer = null
    }

    pop.root.hidden = false
    requestAnimationFrame(() => this._positionPopover(jsEvent))
  }

  _setOptional(valueEl, labelEl, value) {
    if (!valueEl || !labelEl) return
    if (value) {
      valueEl.textContent = value
      valueEl.style.display = ""
      labelEl.style.display = ""
    } else {
      valueEl.style.display = "none"
      labelEl.style.display = "none"
    }
  }

  _positionPopover(jsEvent) {
    const root = this._popover?.root
    if (!root) return
    const margin = 12
    const rect = root.getBoundingClientRect()
    const x = jsEvent?.clientX ?? window.innerWidth / 2
    const y = jsEvent?.clientY ?? window.innerHeight / 2

    let top  = y + margin
    let left = x + margin
    if (left + rect.width  > window.innerWidth  - 16) left = x - rect.width  - margin
    if (top  + rect.height > window.innerHeight - 16) top  = y - rect.height - margin

    root.style.top  = `${Math.max(8, top)}px`
    root.style.left = `${Math.max(8, left)}px`
    root.classList.add("is-visible")
  }

  _hidePopover() {
    const root = this._popover?.root
    if (!root) return
    root.classList.remove("is-visible")
    if (this._hideTimer) clearTimeout(this._hideTimer)
    this._hideTimer = setTimeout(() => {
      root.hidden = true
      this._hideTimer = null
    }, 140)
  }

  _stateTone(state) {
    return {
      scheduled:   "info",
      in_progress: "purple",
      completed:   "success",
      cancelled:   "neutral",
      no_show:     "danger"
    }[state] || "info"
  }

  _formatWhen(date, duration) {
    if (!date) return "—"
    const fmtDate = new Intl.DateTimeFormat(this.localeValue || "ru", {
      day: "numeric", month: "long", weekday: "short"
    }).format(date)
    const fmtTime = new Intl.DateTimeFormat(this.localeValue || "ru", {
      hour: "2-digit", minute: "2-digit"
    }).format(date)
    return `${fmtDate} · ${fmtTime}${duration ? " · " + duration + " мин" : ""}`
  }

  // ─── Agenda sorting ────────────────────────────────────────────────────
  sort(event) {
    const key = event.currentTarget.dataset.sort
    if (this._currentSort === key) {
      this._sortDir[key] = this._sortDir[key] === "asc" ? "desc" : "asc"
    } else {
      this._sortDir[key] = "asc"
      this._currentSort = key
    }
    this._applySort(key, this._sortDir[key])
    this._updateSortArrows()
  }

  _applySort(key, dir) {
    if (!this.hasAgendaTarget) return
    const tbody = this.agendaTarget.querySelector("tbody")
    if (!tbody) return
    const rows = Array.from(tbody.querySelectorAll("tr"))
    rows.sort((a, b) => {
      const av = (a.dataset[key] || "").toLowerCase()
      const bv = (b.dataset[key] || "").toLowerCase()
      if (av < bv) return dir === "asc" ? -1 : 1
      if (av > bv) return dir === "asc" ? 1 : -1
      return 0
    })
    rows.forEach(r => tbody.appendChild(r))
  }

  _updateSortArrows() {
    if (!this.hasAgendaTarget) return
    this.agendaTarget.querySelectorAll("th[data-sort]").forEach(th => {
      const arrow = th.querySelector(".agenda-table__arrow")
      if (!arrow) return
      if (th.dataset.sort === this._currentSort) {
        arrow.textContent = this._sortDir[this._currentSort] === "asc" ? "↑" : "↓"
        arrow.style.opacity = "1"
      } else {
        arrow.textContent = "↕"
        arrow.style.opacity = "0.3"
      }
    })
  }
}
