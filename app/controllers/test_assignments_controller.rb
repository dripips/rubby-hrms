class TestAssignmentsController < ApplicationController
  before_action :set_applicant, only: %i[create]
  before_action :set_assignment, only: %i[update destroy start submit_work review cancel reopen notify]

  def create
    authorize TestAssignment
    @assignment = @applicant.test_assignments.new(assignment_params.merge(created_by: current_user))
    if @assignment.save
      MessageDispatcher.deliver!(
        event:          :test_assignment_sent,
        recipient_type: :candidate,
        payload:        { applicant: @applicant, assignment: @assignment }
      )
      respond_with_card_update(:created, applicant: @applicant)
    else
      redirect_to job_applicant_path(@applicant), alert: @assignment.errors.full_messages.to_sentence
    end
  end

  def update
    authorize @assignment
    if @assignment.update(assignment_params)
      respond_with_card_update(:updated)
    else
      redirect_to job_applicant_path(@assignment.job_applicant_id), alert: @assignment.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @assignment
    @assignment.discard
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(view_context.dom_id(@assignment)) }
      format.html { redirect_to job_applicant_path(@assignment.job_applicant_id, anchor: "assignments"), notice: t("test_assignments.deleted") }
    end
  end

  def start;       transition!(:start) end
  def submit_work; transition!(:submit_work, params: %i[submission_text submission_files]) end
  def review;      transition!(:review, params: %i[score reviewer_notes], extra: { reviewed_by: current_user }) end
  def cancel;      transition!(:cancel) end
  def reopen;      transition!(:reopen) end

  def notify
    authorize @assignment, :update?
    MessageDispatcher.deliver!(
      event:          :test_assignment_sent,
      recipient_type: :candidate,
      payload:        { applicant: @assignment.job_applicant, assignment: @assignment }
    )
    respond_to do |format|
      notice = t("test_assignments.notified", email: @assignment.job_applicant.email.presence || "—")
      format.turbo_stream do
        flash.now[:notice] = notice
        render turbo_stream: turbo_stream_for_card
      end
      format.html { redirect_to job_applicant_path(@assignment.job_applicant_id, anchor: "assignments"), notice: notice }
    end
  rescue StandardError => e
    redirect_to job_applicant_path(@assignment.job_applicant_id, anchor: "assignments"),
                alert: t("test_assignments.notify_failed", err: e.message.first(150))
  end

  private

  def set_applicant
    @applicant = JobApplicant.kept.find(params[:job_applicant_id])
  end

  def set_assignment
    @assignment = TestAssignment.kept.find(params[:id])
  end

  def assignment_params
    params.require(:test_assignment).permit(
      :title, :description, :requirements, :deadline,
      :submission_text, :score, :reviewer_notes,
      brief_files: [], submission_files: []
    )
  end

  def transition!(event, params: [], extra: {})
    authorize @assignment, :update?
    update_attrs = extra.dup
    Array(params).each do |key|
      next unless self.params[:test_assignment]&.key?(key.to_s)
      update_attrs[key] = self.params[:test_assignment][key]
    end
    update_attrs[:submission_files] = self.params[:test_assignment][:submission_files] if event == :submit_work && self.params[:test_assignment]&.key?(:submission_files)

    @assignment.transaction do
      @assignment.update!(update_attrs.except(:submission_files)) if update_attrs.except(:submission_files).any?
      if event == :submit_work && self.params[:test_assignment]&.key?(:submission_files)
        @assignment.submission_files.attach(self.params[:test_assignment][:submission_files])
      end
      @assignment.public_send("#{event}!")
    end

    respond_with_card_update(:"transitioned.#{event}")
  rescue AASM::InvalidTransition, ActiveRecord::RecordInvalid => e
    redirect_to job_applicant_path(@assignment.job_applicant_id), alert: e.message
  end

  # Реактивный ответ: turbo_stream replace одной карточки + flash-notice;
  # fallback на HTML redirect для не-Turbo клиентов.
  def respond_with_card_update(notice_key, applicant: nil)
    notice = t("test_assignments.#{notice_key}")
    target_applicant = applicant || @assignment.job_applicant

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = notice
        if applicant  # create: append to list
          render turbo_stream: turbo_stream.append(
            "test_assignments_list",
            partial: "test_assignments/card",
            locals:  { assignment: @assignment, applicant: target_applicant }
          )
        else  # update/transition: replace one card
          render turbo_stream: turbo_stream_for_card(target_applicant)
        end
      end
      format.html { redirect_to job_applicant_path(target_applicant.id, anchor: "assignments"), notice: notice }
    end
  end

  def turbo_stream_for_card(applicant = nil)
    target_applicant = applicant || @assignment.job_applicant
    turbo_stream.replace(
      view_context.dom_id(@assignment),
      partial: "test_assignments/card",
      locals:  { assignment: @assignment, applicant: target_applicant }
    )
  end
end
