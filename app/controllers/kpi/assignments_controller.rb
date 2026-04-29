module Kpi
  class AssignmentsController < ApplicationController
    before_action :set_company
    before_action :set_assignment, only: %i[edit update destroy]

    def index
      authorize KpiAssignment

      @period = (params[:period].presence || "current_week").to_s
      from, to = period_range(@period)
      @period_from = from
      @period_to   = to

      @assignments = policy_scope(KpiAssignment)
                       .joins(:employee, :kpi_metric)
                       .includes(:employee, :kpi_metric)
                       .where(kpi_metrics: { company_id: @company.id })

      @assignments = @assignments.overlapping(from, to) if from && to
      @assignments = @assignments.where(employee_id: params[:employee_id])     if params[:employee_id].present?
      @assignments = @assignments.where(kpi_metric_id: params[:kpi_metric_id]) if params[:kpi_metric_id].present?

      @assignments = @assignments.ordered_by_period

      @employees = Employee.kept.where(company: @company).order(:last_name)
      @metrics   = KpiMetric.active.where(company: @company).order(:name)
      @new_assignment = KpiAssignment.new(period_start: Date.current.beginning_of_week, period_end: Date.current.end_of_week, weight: 1.0)
    end

    def create
      @assignment = KpiAssignment.new(assignment_params)
      authorize @assignment
      if @assignment.save
        redirect_to kpi_assignments_path, notice: t("kpi.assignments.created")
      else
        redirect_to kpi_assignments_path, alert: @assignment.errors.full_messages.to_sentence
      end
    end

    def edit
      authorize @assignment
    end

    def update
      authorize @assignment
      if @assignment.update(assignment_params)
        redirect_to kpi_assignments_path, notice: t("kpi.assignments.updated")
      else
        redirect_to kpi_assignments_path, alert: @assignment.errors.full_messages.to_sentence
      end
    end

    def destroy
      authorize @assignment
      @assignment.destroy
      redirect_to kpi_assignments_path, notice: t("kpi.assignments.deleted")
    end

    private

    def set_company
      @company = Company.kept.first
      redirect_to root_path, alert: t("errors.company_missing", default: "Компания не настроена") if @company.nil?
    end

    def set_assignment
      @assignment = KpiAssignment.find(params[:id])
    end

    def assignment_params
      params.require(:kpi_assignment).permit(:employee_id, :kpi_metric_id, :period_start, :period_end, :target, :weight, :description)
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
