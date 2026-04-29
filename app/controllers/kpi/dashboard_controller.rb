module Kpi
  class DashboardController < ApplicationController
    before_action :set_company

    def show
      @period = (params[:period].presence || "current_week").to_s
      from, to = period_range(@period)
      @period_from = from
      @period_to   = to

      @my_assignments       = my_assignments(from, to)
      @my_avg               = average_score_for(@my_assignments)

      @team_top, @team_bot  = team_leaderboard(from, to) if manager_or_higher?
      @team_avg             = team_avg_score(from, to)   if manager_or_higher?

      @company_avg          = company_avg_score(from, to) if hr_or_higher?
      @company_trend        = company_score_trend         if hr_or_higher?
      @metric_distribution  = company_metric_distribution(from, to) if hr_or_higher?
      @recent_evaluations   = recent_evaluations
    end

    private

    def set_company
      @company = Company.kept.first
      redirect_to root_path, alert: t("errors.company_missing", default: "Компания не настроена") if @company.nil?
    end

    def manager_or_higher? = current_user.role_superadmin? || current_user.role_hr? || current_user.role_manager?
    def hr_or_higher?      = current_user.role_superadmin? || current_user.role_hr?

    def my_assignments(from, to)
      return KpiAssignment.none unless current_user.employee
      scope = KpiAssignment.where(employee: current_user.employee).includes(:kpi_metric, :kpi_evaluations)
      scope = scope.overlapping(from, to) if from && to
      scope.order(period_start: :desc)
    end

    def average_score_for(assignments)
      latest_scores = assignments.map { |a| a.latest_evaluation&.score }.compact
      return nil if latest_scores.empty?
      (latest_scores.sum / latest_scores.size).round(1)
    end

    def team_employees
      return Employee.kept.where(company: @company) if hr_or_higher?
      current_user.employee&.reports&.kept || Employee.none
    end

    def team_avg_score(from, to)
      ids = team_employees.pluck(:id)
      return nil if ids.empty?
      avg_score(KpiEvaluation.joins(:kpi_assignment)
                              .where(kpi_assignments: { employee_id: ids })
                              .then { |s| from && to ? s.where(kpi_assignments: { period_start: ..to, period_end: from.. }) : s })
    end

    def team_leaderboard(from, to, limit: 5)
      ids = team_employees.pluck(:id)
      return [[], []] if ids.empty?

      scope = KpiEvaluation
                .joins(kpi_assignment: :employee)
                .where(kpi_assignments: { employee_id: ids })
      scope = scope.where(kpi_assignments: { period_start: ..to, period_end: from.. }) if from && to

      grouped = scope.group("employees.id").average(:score)
      ranked = grouped.map { |emp_id, avg| [Employee.find(emp_id), avg.to_f.round(1)] }
                      .sort_by { |_, avg| -avg }

      [ranked.first(limit), ranked.last(limit).reverse]
    end

    def company_avg_score(from, to)
      scope = KpiEvaluation.joins(kpi_assignment: { kpi_metric: :company })
                            .where(kpi_metrics: { company_id: @company.id })
      scope = scope.where(kpi_assignments: { period_start: ..to, period_end: from.. }) if from && to
      avg_score(scope)
    end

    def company_score_trend(weeks: 8)
      result = []
      weeks.downto(1) do |i|
        wk = i.weeks.ago.to_date
        from = wk.beginning_of_week
        to   = wk.end_of_week
        scope = KpiEvaluation.joins(kpi_assignment: { kpi_metric: :company })
                              .where(kpi_metrics: { company_id: @company.id })
                              .where(kpi_assignments: { period_start: ..to, period_end: from.. })
        avg = scope.average(:score)
        result << { label: from.strftime("%-d %b"), avg: avg ? avg.to_f.round(1) : nil }
      end
      result
    end

    def company_metric_distribution(from, to)
      scope = KpiEvaluation.joins(kpi_assignment: :kpi_metric)
                            .where(kpi_metrics: { company_id: @company.id })
      scope = scope.where(kpi_assignments: { period_start: ..to, period_end: from.. }) if from && to
      grouped = scope.group("kpi_metrics.id", "kpi_metrics.name", "kpi_metrics.unit").average(:score)
      grouped.map { |(_id, name, unit), avg| { name: name, unit: unit, avg: avg.to_f.round(1) } }
              .sort_by { |x| -x[:avg] }
    end

    def recent_evaluations(limit: 8)
      scope = KpiEvaluationPolicy::Scope.new(current_user, KpiEvaluation).resolve
                .includes(kpi_assignment: %i[employee kpi_metric], evaluator: :employee)
                .order(evaluated_at: :desc)
      scope.limit(limit)
    end

    def avg_score(scope)
      avg = scope.average(:score)
      avg ? avg.to_f.round(1) : nil
    end

    def period_range(key)
      today = Date.current
      case key
      when "current_week"    then [today.beginning_of_week, today.end_of_week]
      when "current_month"   then [today.beginning_of_month, today.end_of_month]
      when "current_quarter" then [today.beginning_of_quarter, today.end_of_quarter]
      when "all"             then [nil, nil]
      else
        [today.beginning_of_week, today.end_of_week]
      end
    end
  end
end
