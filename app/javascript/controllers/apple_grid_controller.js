import { Controller } from "@hotwired/stimulus"

// Используем простые ASCII-стрелки + русские слова — Inter точно отрисует.
const RU_LANG = {
  pagination: {
    page_size: "Размер страницы", page_title: "Страница",
    first: "Первая", first_title: "Первая",
    last:  "Последняя", last_title:  "Последняя",
    prev:  "← Назад", prev_title:  "Назад",
    next:  "Вперёд →", next_title:  "Вперёд",
    all:   "Все",
    counter: { showing: "Показано", of: "из", rows: "строк", pages: "стр." }
  },
  data:    { loading: "Загрузка...", error: "Ошибка" },
  groups:  { item: "запись", items: "записей" },
  ajax:    { loading: "Загрузка...", error: "Ошибка" },
  columns: {}
}

const EN_LANG = {
  pagination: {
    page_size: "Page size", page_title: "Page",
    first: "First", first_title: "First", last: "Last", last_title: "Last",
    prev:  "← Prev", prev_title:  "Prev",  next: "Next →", next_title:  "Next",
    all:   "All",
    counter: { showing: "Showing", of: "of", rows: "rows", pages: "pages" }
  },
  data:    { loading: "Loading...", error: "Error" },
  groups:  { item: "row", items: "rows" },
  ajax:    { loading: "Loading...", error: "Error" },
  columns: {}
}

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content || ""
}

class DbStore {
  constructor(key) { this.key = key; this.cache = null }

  async load() {
    try {
      const r = await fetch(`/grid_preferences/${encodeURIComponent(this.key)}`, {
        credentials: "same-origin", headers: { Accept: "application/json" }
      })
      this.cache = r.ok ? await r.json() : {}
    } catch { this.cache = {} }
    return this.cache
  }

  read(kind)  { return this.cache && this.cache[kind] ? this.cache[kind] : false }

  write(kind, data) {
    if (!this.cache) this.cache = {}
    this.cache[kind] = data
    fetch(`/grid_preferences/${encodeURIComponent(this.key)}/${encodeURIComponent(kind)}`, {
      method: "PUT", credentials: "same-origin",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken(), Accept: "application/json" },
      body: JSON.stringify({ data })
    }).catch(() => {})
  }
}

export default class extends Controller {
  static targets = ["grid", "densityToggle", "densityLabel"]
  static values  = {
    url:             String,
    columns:         Array,
    storageKey:      { type: String, default: "" },
    pageSize:        { type: Number, default: 50 },
    rowUrlTemplate:  { type: String, default: "" },
    locale:          { type: String, default: "ru" }
  }

  async connect() {
    if (typeof Tabulator === "undefined") { setTimeout(() => this.connect(), 80); return }

    const host = this.hasGridTarget ? this.gridTarget : this.element

    this.store = this.storageKeyValue ? new DbStore(this.storageKeyValue) : null
    if (this.store) await this.store.load()

    // Авто-инжектим класс на колонки с headerFilter: "list",
    // чтобы CSS мог дорисовать chevron-стрелку справа от инпута.
    const columns = (this.columnsValue || []).map(c => {
      if (c.headerFilter === "list") {
        const existing = c.cssClass ? `${c.cssClass} ` : ""
        return { ...c, cssClass: `${existing}is-select-filter` }
      }
      return c
    })

    this.table = new Tabulator(host, {
      ajaxURL: this.urlValue,
      pagination: true,
      paginationMode: "remote",
      paginationSize: this.pageSizeValue,
      paginationSizeSelector: [25, 50, 100, 200],
      sortMode: "remote",
      filterMode: "remote",
      headerFilterLiveFilterDelay: 280,
      layout: "fitColumns",
      movableColumns: true,
      resizableColumnFit: true,
      placeholder: this.localeValue === "ru" ? "Нет данных" : "No data",
      columnDefaults: {
        resizable: true,
        headerSort: true,
        headerHozAlign: "left",
        minWidth: 110
      },
      // Persistence: per-user в БД через DbStore (/grid_preferences/:key/:kind).
      // Тaбulator вызывает reader/writer-функции синхронно — DbStore.read берёт
      // из cache (загружен в connect через await), write шлёт PUT fire-and-forget.
      // Каждый KIND (columns, sort, filter, headerFilter, page) сохраняется
      // отдельной записью в grid_preferences (uniq[user_id, key, kind]).
      persistence: this.store ? {
        sort:         true,
        filter:       true,
        headerFilter: true,
        page:         true,
        columns:      true
      } : false,
      persistenceID: this.storageKeyValue || "default",
      persistenceReaderFunc: this.store ? ((_id, type) => this.store.read(type) || false) : undefined,
      persistenceWriterFunc: this.store ? ((_id, type, data) => this.store.write(type, data)) : undefined,
      columns: columns,
      langs:  { ru: RU_LANG, en: EN_LANG },
      locale: this.localeValue
    })

    if (this.rowUrlTemplateValue) {
      host.classList.add("apple-grid--clickable")
      this.table.on("rowClick", (_e, row) => {
        const id = row.getData().id
        if (id) window.location.href = this.rowUrlTemplateValue.replace("{id}", id)
      })
    }

    // Restore density preference from DB.
    const density = (this.store?.read("density") || {}).value
    if (density === "compact") this._setDensity("compact", { save: false })

    // Build the columns dropdown content if it's present on the page.
    this.table.on("tableBuilt", () => this._renderColumnsDropdown())

    // Measure real scrollbar width on every redraw and align the header.
    // Tabulator's built-in scrollbar compensation is set once at init and
    // doesn't pick up custom CSS scrollbar widths or runtime layout changes.
    const syncHeader = () => {
      const holder = this.element.querySelector(".tabulator-tableholder")
      const header = this.element.querySelector(".tabulator-header")
      if (!holder || !header) return
      const sbw = holder.offsetWidth - holder.clientWidth
      header.style.paddingRight = sbw + "px"
    }
    this.table.on("renderComplete", syncHeader)
    this.table.on("dataLoaded",     syncHeader)
    window.addEventListener("resize", syncHeader)
    setTimeout(syncHeader, 100)
  }

  exportCsv()  { this.table?.download("csv",  "employees.csv",  { bom: true, delimiter: ";" }) }
  exportXlsx() { this.table?.download("xlsx", "employees.xlsx", { sheetName: "Employees" }) }
  exportJson() { this.table?.download("json", "employees.json") }
  refresh()    { this.table?.replaceData() }

  // Prevent dropdown auto-close when clicking checkboxes inside.
  stopPropagation(event) { event?.stopPropagation() }

  toggleDensity(event) {
    event?.preventDefault()
    const next = this._currentDensity() === "compact" ? "comfortable" : "compact"
    this._setDensity(next)
  }

  _currentDensity() {
    return this.element.classList.contains("apple-grid--compact") ? "compact" : "comfortable"
  }

  _setDensity(mode, { save = true } = {}) {
    this.element.classList.toggle("apple-grid--compact", mode === "compact")
    if (this.hasDensityToggleTarget) {
      this.densityToggleTarget.setAttribute("aria-pressed", mode === "compact" ? "true" : "false")
    }
    if (this.hasDensityLabelTarget) {
      const ru = this.localeValue === "ru"
      this.densityLabelTarget.textContent = mode === "compact"
        ? (ru ? "Компактный" : "Compact")
        : (ru ? "Стандартный" : "Standard")
    }
    if (save && this.store) this.store.write("density", { value: mode })
    // Force redraw so row heights update.
    this.table?.redraw(true)
  }

  _renderColumnsDropdown() {
    const list = document.getElementById("columnsDropdownList")
    if (!list || !this.table) return

    list.innerHTML = ""
    this.table.getColumns().forEach(col => {
      const def = col.getDefinition()
      if (!def.field) return

      const li = document.createElement("li")
      li.className = "columns-dropdown__item"

      const id = `col-tgl-${def.field}`
      const visible = col.isVisible()

      li.innerHTML = `
        <input type="checkbox" class="columns-dropdown__check" id="${id}" ${visible ? "checked" : ""}>
        <label for="${id}" class="columns-dropdown__label">${def.title || def.field}</label>
      `
      li.querySelector("input").addEventListener("change", e => {
        e.target.checked ? col.show() : col.hide()
      })
      // Keep dropdown open on item click.
      li.addEventListener("click", e => e.stopPropagation())
      list.appendChild(li)
    })
  }

  disconnect() { this.table?.destroy() }
}
