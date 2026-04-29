class OnboardingProcessesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_process, only: %i[show update destroy activate complete cancel]

  def index
    @processes = policy_scope(OnboardingProcess).recent.includes(:employee, :template, :mentor)
    @active    = @processes.where(state: "active")
    @drafts    = @processes.where(state: "draft")
    @completed = @processes.where(state: %w[completed cancelled]).limit(20)
  end

  def show
    authorize @process
  end

  def new
    employee = Employee.kept.find(params[:employee_id]) if params[:employee_id].present?
    @process = OnboardingProcess.new(employee: employee, started_on: Date.current)
    authorize @process
    @templates = ProcessTemplate.for_company(Company.kept.first).onboarding.active.ordered
  end

  def create
    @process = OnboardingProcess.new(process_params.merge(created_by: current_user))
    authorize @process
    if @process.save
      @process.materialize_from_template!
      @process.activate! if @process.may_activate?
      redirect_to onboarding_process_path(@process), notice: t("flash.created", default: "Создано")
    else
      @templates = ProcessTemplate.for_company(Company.kept.first).onboarding.active.ordered
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @process.update(process_params)
      redirect_to onboarding_process_path(@process), notice: t("flash.updated")
    else
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    @process.discard
    redirect_to onboarding_processes_path, notice: t("flash.deleted")
  end

  def activate
    @process.activate! if @process.may_activate?
    redirect_to onboarding_process_path(@process)
  end

  def complete
    @process.complete! if @process.may_complete?
    redirect_to onboarding_process_path(@process)
  end

  def cancel
    @process.cancel! if @process.may_cancel?
    redirect_to onboarding_process_path(@process)
  end

  private

  def set_process
    @process = OnboardingProcess.find(params[:id])
  end

  def process_params
    params.require(:onboarding_process).permit(:employee_id, :template_id, :mentor_id, :started_on, :target_complete_on)
  end
end
