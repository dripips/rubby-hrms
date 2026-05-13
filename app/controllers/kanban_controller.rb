class KanbanController < ApplicationController
  before_action :set_company

  def index
    authorize JobApplicant, :index?

    scope = policy_scope(JobApplicant).where(company: @company).includes(:job_opening, :owner)
    scope = scope.where(job_opening_id: params[:job_opening_id]) if params[:job_opening_id].present?
    scope = scope.where(owner_id:        params[:owner_id])      if params[:owner_id].present?
    scope = scope.where(source:          params[:source])        if params[:source].present?

    @stages = JobApplicant::STAGES
    @columns = @stages.index_with do |s|
      scope.kept.where(stage: s).order(stage_changed_at: :desc, applied_at: :desc).to_a
    end

    @openings   = JobOpening.kept.where(company: @company).order(:title)
    @recruiters = User.kept.where(role: %i[hr superadmin manager])
  end

  private

  def set_company
    @company = current_company
    redirect_to root_path, alert: "Компания не настроена" if @company.nil?
  end
end
