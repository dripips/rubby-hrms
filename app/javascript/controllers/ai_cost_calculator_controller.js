import { Controller } from "@hotwired/stimulus"

// Live-калькулятор стоимости AI-задач: при смене модели или бюджета
// пересчитывает каждую строку таблицы (cost per run + runs per budget).
//
// HTML:
//   <div data-controller="ai-cost-calculator"
//        data-ai-cost-calculator-models-value='{"gpt-5-nano": {"input": 0.05, "output": 0.40}, ...}'
//        data-ai-cost-calculator-tasks-value='{"analyze_resume": {"input": 2500, "output": 600}, ...}'>
//     <input type="radio" name="..." value="gpt-5-nano"
//            data-ai-cost-calculator-target="model"
//            data-action="change->ai-cost-calculator#recalc">
//     <input type="number" data-ai-cost-calculator-target="budget"
//            data-action="input->ai-cost-calculator#recalc change->ai-cost-calculator#recalc">
//
//     <span data-ai-cost-calculator-target="modelLabel"></span>
//     <span data-ai-cost-calculator-target="budgetLabel"></span>
//
//     <tr data-task="analyze_resume">
//       <td data-ai-cost-calculator-target="cost"></td>
//       <td data-ai-cost-calculator-target="runs"></td>
//     </tr>
//   </div>
export default class extends Controller {
  static values = {
    models: Object,
    tasks:  Object,
    modelLabels: Object
  }
  static targets = ["model", "budget", "cost", "runs", "modelLabel", "budgetLabel"]

  connect() {
    this.recalc()
  }

  recalc() {
    const modelKey = this._activeModelKey()
    const model    = this.modelsValue[modelKey]
    if (!model) return

    const budget = parseFloat(this.hasBudgetTarget ? this.budgetTarget.value : 5) || 0

    // Подсветка выбранной карточки модели — добавим класс is-selected на label
    // активного радио, уберём с остальных.
    this.modelTargets.forEach((radio) => {
      const label = radio.closest(".ai-models__option")
      if (label) label.classList.toggle("is-selected", radio.checked)
    })

    if (this.hasModelLabelTarget) {
      this.modelLabelTarget.textContent = this.modelLabelsValue[modelKey] || modelKey
    }
    if (this.hasBudgetLabelTarget) {
      this.budgetLabelTarget.textContent = budget.toString()
    }

    // Каждая строка-задача имеет data-task="<key>" и таргеты cost/runs внутри.
    this.element.querySelectorAll("[data-task]").forEach((row) => {
      const taskKey = row.dataset.task
      const sizes   = this.tasksValue[taskKey]
      if (!sizes) return

      const cost = (sizes.input  * model.input  / 1_000_000) +
                   (sizes.output * model.output / 1_000_000)

      const runs = cost > 0 && budget > 0 ? Math.floor(budget / cost) : 0

      const costEl = row.querySelector("[data-ai-cost-calculator-target='cost']")
      const runsEl = row.querySelector("[data-ai-cost-calculator-target='runs']")
      if (costEl) costEl.textContent = `~$${cost.toFixed(4)}`
      if (runsEl) runsEl.textContent = runs.toLocaleString("en-US")
    })
  }

  _activeModelKey() {
    const checked = this.modelTargets.find((m) => m.checked)
    return checked ? checked.value : null
  }
}
