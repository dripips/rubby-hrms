module Kpi
  class MetricsController < ApplicationController
    before_action :set_company
    before_action :set_metric, only: %i[edit update destroy]

    def index
      authorize KpiMetric
      @metrics = policy_scope(KpiMetric).where(company: @company).order(active: :desc, name: :asc)
      @new_metric = KpiMetric.new(company: @company, target_direction: :maximize, weight_default: 1.0, active: true)
    end

    def create
      authorize KpiMetric
      @metric = KpiMetric.new(metric_params.merge(company: @company))
      if @metric.save
        redirect_to kpi_metrics_path, notice: t("kpi.metrics.created")
      else
        redirect_to kpi_metrics_path, alert: @metric.errors.full_messages.to_sentence
      end
    end

    def edit
      authorize @metric
    end

    def update
      authorize @metric
      if @metric.update(metric_params)
        redirect_to kpi_metrics_path, notice: t("kpi.metrics.updated")
      else
        redirect_to kpi_metrics_path, alert: @metric.errors.full_messages.to_sentence
      end
    end

    def destroy
      authorize @metric
      if @metric.kpi_assignments.any?
        @metric.update(active: false)
        redirect_to kpi_metrics_path, notice: t("kpi.metrics.deactivated_with_history")
      else
        @metric.discard
        redirect_to kpi_metrics_path, notice: t("kpi.metrics.deleted")
      end
    end

    private

    def set_company
      @company = current_company
      redirect_to root_path, alert: t("errors.company_missing", default: "Компания не настроена") if @company.nil?
    end

    def set_metric
      @metric = KpiMetric.kept.where(company: @company).find(params[:id])
    end

    def metric_params
      params.require(:kpi_metric).permit(:name, :code, :unit, :target_direction, :weight_default, :active)
    end
  end
end
