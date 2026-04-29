class OnboardingTasksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_task

  def update
    authorize @task

    case params[:event]
    when "complete" then @task.complete! if @task.may_complete?
    when "skip"     then @task.skip!     if @task.may_skip?
    when "reopen"   then @task.reopen!   if @task.may_reopen?
    when "start"    then @task.start!    if @task.may_start?
    end

    @task.update(assignee_id: params[:assignee_id]) if params.key?(:assignee_id)

    respond_to do |format|
      format.turbo_stream do
        process_obj = @task.onboarding_process
        render turbo_stream: [
          turbo_stream.replace("onboarding-task-#{@task.id}",
                               partial: "onboarding_processes/task",
                               locals: { task: @task, process: process_obj }),
          turbo_stream.replace("onboarding-progress-#{process_obj.id}",
                               partial: "onboarding_processes/progress",
                               locals: { process: process_obj })
        ]
      end
      format.html { redirect_to onboarding_process_path(@task.onboarding_process) }
    end
  end

  private

  def set_task = (@task = OnboardingTask.find(params[:id]))
end
