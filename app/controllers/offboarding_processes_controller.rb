class OffboardingProcessesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_process, only: %i[show update destroy activate complete cancel]

  def index
    @processes = policy_scope(OffboardingProcess).recent.includes(:employee, :template)
    @active    = @processes.where(state: "active")
    @drafts    = @processes.where(state: "draft")
    @completed = @processes.where(state: %w[completed cancelled]).limit(20)
  end

  def show
    authorize @process
  end

  def new
    employee = Employee.kept.find(params[:employee_id]) if params[:employee_id].present?
    @process = OffboardingProcess.new(employee: employee, last_day: 14.days.from_now.to_date, reason: "voluntary")
    authorize @process
    @templates = ProcessTemplate.for_company(Company.kept.first).offboarding.active.ordered
  end

  def create
    @process = OffboardingProcess.new(process_params.merge(created_by: current_user))
    authorize @process
    if @process.save
      @process.materialize_from_template!
      @process.activate! if @process.may_activate?
      redirect_to offboarding_process_path(@process), notice: t("flash.created")
    else
      @templates = ProcessTemplate.for_company(Company.kept.first).offboarding.active.ordered
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @process.update(process_params)
      redirect_to offboarding_process_path(@process), notice: t("flash.updated")
    else
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    @process.discard
    redirect_to offboarding_processes_path, notice: t("flash.deleted")
  end

  def activate = (@process.activate!  if @process.may_activate?; redirect_to(offboarding_process_path(@process)))
  def complete = (@process.complete!  if @process.may_complete?; redirect_to(offboarding_process_path(@process)))
  def cancel   = (@process.cancel!    if @process.may_cancel?;   redirect_to(offboarding_process_path(@process)))

  private

  def set_process
    @process = OffboardingProcess.find(params[:id])
  end

  def process_params
    params.require(:offboarding_process).permit(:employee_id, :template_id, :reason, :last_day)
  end
end
