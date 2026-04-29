module Kpi
  class EvaluationsController < ApplicationController
    before_action :set_company

    def index
      authorize KpiEvaluation

      @period = (params[:period].presence || "current_week").to_s
      from, to = period_range(@period)
      @period_from = from
      @period_to   = to

      assignment_scope = KpiAssignmentPolicy::Scope.new(current_user, KpiAssignment).resolve
                          .joins(:kpi_metric, :employee)
                          .includes(:employee, :kpi_metric, :kpi_evaluations)
                          .where(kpi_metrics: { company_id: @company.id })

      assignment_scope = assignment_scope.overlapping(from, to) if from && to
      assignment_scope = assignment_scope.where(employee_id: params[:employee_id]) if params[:employee_id].present?

      @assignments_by_employee = assignment_scope
                                   .order("employees.last_name, employees.first_name, kpi_metrics.name")
                                   .group_by(&:employee)

      @employees = team_employees
    end

    def create
      assignment = KpiAssignment.find(eval_params[:kpi_assignment_id])
      authorize KpiEvaluation
      raise Pundit::NotAuthorizedError unless KpiAssignmentPolicy.new(current_user, assignment).update?

      @evaluation = assignment.kpi_evaluations.new(
        evaluator:    current_user,
        actual_value: eval_params[:actual_value].presence,
        score:        eval_params[:score].presence,
        notes:        eval_params[:notes].presence,
        evaluated_at: Time.current
      )

      respond_to do |format|
        if @evaluation.save
          format.turbo_stream {
            render turbo_stream: turbo_stream.replace(
              "kpi-eval-row-#{assignment.id}",
              partial: "kpi/evaluations/row",
              locals:  { assignment: assignment.reload, just_saved: true }
            )
          }
          format.html { redirect_to kpi_evaluations_path, notice: t("kpi.evaluations.saved") }
        else
          format.turbo_stream {
            render turbo_stream: turbo_stream.replace(
              "kpi-eval-row-#{assignment.id}",
              partial: "kpi/evaluations/row",
              locals:  { assignment: assignment, error: @evaluation.errors.full_messages.to_sentence }
            )
          }
          format.html { redirect_to kpi_evaluations_path, alert: @evaluation.errors.full_messages.to_sentence }
        end
      end
    end

    private

    def set_company
      @company = Company.kept.first
      redirect_to root_path, alert: t("errors.company_missing", default: "Компания не настроена") if @company.nil?
    end

    def eval_params
      params.require(:kpi_evaluation).permit(:kpi_assignment_id, :actual_value, :score, :notes)
    end

    def team_employees
      if current_user.role_superadmin? || current_user.role_hr?
        Employee.kept.where(company: @company).order(:last_name)
      elsif current_user.role_manager? && current_user.employee
        current_user.employee.reports.kept.order(:last_name)
      else
        Employee.none
      end
    end

    def period_range(key)
      today = Date.current
      case key
      when "current_week"    then [ today.beginning_of_week, today.end_of_week ]
      when "current_month"   then [ today.beginning_of_month, today.end_of_month ]
      when "current_quarter" then [ today.beginning_of_quarter, today.end_of_quarter ]
      when "all"             then [ nil, nil ]
      else
        [ today.beginning_of_week, today.end_of_week ]
      end
    end
  end
end
