class OffboardingTasksController < ApplicationController
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
        process_obj = @task.offboarding_process
        render turbo_stream: [
          turbo_stream.replace("offboarding-task-#{@task.id}",
                               partial: "offboarding_processes/task",
                               locals: { task: @task, process: process_obj }),
          turbo_stream.replace("offboarding-progress-#{process_obj.id}",
                               partial: "offboarding_processes/progress",
                               locals: { process: process_obj })
        ]
      end
      format.html { redirect_to offboarding_process_path(@task.offboarding_process) }
    end
  end

  private

  def set_task = (@task = OffboardingTask.find(params[:id]))
end
