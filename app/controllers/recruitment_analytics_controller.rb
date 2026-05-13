class RecruitmentAnalyticsController < ApplicationController
  before_action :set_company

  def index
    authorize :recruitment_analytics, :index?

    @period     = RecruitmentAnalytics::PERIODS.key?(params[:period].to_s) ? params[:period] : "90"
    @analytics  = RecruitmentAnalytics.new(company: @company, period: @period)

    @kpi          = @analytics.kpi_cards
    @funnel       = @analytics.funnel
    @sources      = @analytics.source_effectiveness
    @distribution = @analytics.stage_distribution
    @recruiters   = @analytics.recruiter_breakdown
  end

  private

  def set_company
    @company = current_company
    redirect_to root_path, alert: "Компания не настроена" if @company.nil?
  end
end
