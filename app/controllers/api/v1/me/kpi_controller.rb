class Api::V1::Me::KpiController < Api::V1::BaseController
  def index
    emp = current_user.employee
    return render(json: { "data" => [] }) unless emp

    rows = emp.kpi_assignments.includes(:kpi_metric, :kpi_evaluations).map do |a|
      {
        "id"           => a.id,
        "metric"       => a.kpi_metric&.name,
        "target"       => a.target,
        "weight"       => a.weight,
        "period_start" => a.period_start,
        "period_end"   => a.period_end,
        "evaluations"  => a.kpi_evaluations.order(evaluated_at: :desc).map do |e|
          { "score" => e.score, "actual_value" => e.actual_value,
            "evaluated_at" => e.evaluated_at, "notes" => e.notes }
        end
      }
    end
    render json: { "data" => rows }
  end
end
