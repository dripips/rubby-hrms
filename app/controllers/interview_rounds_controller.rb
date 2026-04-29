class InterviewRoundsController < ApplicationController
  before_action :set_applicant, only: %i[create]
  before_action :set_round,     only: %i[update destroy start complete cancel no_show reopen]

  def index
    authorize InterviewRound
    @scope = InterviewRound.kept
                           .includes(:job_applicant, :interviewer, job_applicant: :job_opening)
                           .order(scheduled_at: :desc)
    @scope = @scope.where(state: params[:state])              if params[:state].present? && InterviewRound::STATES.include?(params[:state])
    @scope = @scope.where(kind:  params[:kind])               if params[:kind].present? && InterviewRound::KINDS.include?(params[:kind])
    @scope = @scope.where(interviewer_id: params[:interviewer_id]) if params[:interviewer_id].present?

    case params[:period]
    when "upcoming" then @scope = @scope.where("scheduled_at >= ?", Time.current).reorder(scheduled_at: :asc)
    when "past"     then @scope = @scope.where("scheduled_at < ?",  Time.current)
    when "today"    then @scope = @scope.where(scheduled_at: Time.current.all_day)
    when "week"     then @scope = @scope.where(scheduled_at: Time.current.beginning_of_week..Time.current.end_of_week)
    end

    @rounds = @scope.limit(200)
    @counts = {
      total:     InterviewRound.kept.count,
      upcoming:  InterviewRound.kept.where("scheduled_at >= ?", Time.current).where(state: "scheduled").count,
      completed: InterviewRound.kept.where(state: "completed").count
    }
    @recruiters = User.kept.where(role: %i[hr superadmin manager]).order(:email)
  end

  def create
    authorize InterviewRound
    @round = @applicant.interview_rounds.new(round_params.merge(created_by: current_user))

    if @round.save
      # Если кандидат всё ещё в applied/screening — автоматически переводим
      # в стадию interview (с записью в историю переходов).
      if %w[applied screening].include?(@applicant.stage)
        @applicant.transition_to!("interview", user: current_user,
                                  comment: "Запланировано интервью: #{@round.kind_label}")
      end

      notify_interviewer(@round, :scheduled)

      flash.now[:notice] = t("interview_rounds.created", default: "Интервью запланировано")
      render_interviews_panel(@applicant)
    else
      redirect_to job_applicant_path(@applicant), alert: @round.errors.full_messages.to_sentence
    end
  end

  def update
    authorize @round
    attrs = round_params.to_h
    attrs[:competency_scores] = clean_scores(attrs[:competency_scores]) if attrs.key?(:competency_scores)
    attrs[:overall_score] = nil

    if @round.update(attrs)
      @round.update_column(:overall_score, @round.calculate_overall_score)
      flash.now[:notice] = t("interview_rounds.updated", default: "Интервью обновлено")
      render_interviews_panel(@round.job_applicant)
    else
      redirect_to job_applicant_path(@round.job_applicant_id), alert: @round.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @round
    @round.discard
    flash.now[:notice] = t("interview_rounds.deleted", default: "Интервью удалено")
    render_interviews_panel(@round.job_applicant)
  end

  def start;    transition!(:start) end
  def complete; transition!(:complete, persist_scorecard: true) end
  def cancel
    notify_interviewer(@round, :cancelled) if @round.scheduled?
    transition!(:cancel)
  end
  def no_show;  transition!(:mark_no_show) end
  def reopen;   transition!(:reopen) end

  private

  def set_applicant
    @applicant = JobApplicant.kept.find(params[:job_applicant_id])
  end

  def set_round
    @round = InterviewRound.kept.find(params[:id])
  end

  def round_params
    params.require(:interview_round).permit(
      :kind, :scheduled_at, :duration_minutes, :location, :meeting_url,
      :interviewer_id, :recommendation, :notes, :decision_comment,
      competency_scores: {}
    )
  end

  def clean_scores(raw)
    return {} unless raw.is_a?(Hash) || raw.is_a?(ActionController::Parameters)

    raw = raw.permit!.to_h if raw.respond_to?(:permit!)
    raw.each_with_object({}) do |(k, v), acc|
      n = v.to_i
      acc[k.to_s] = n if n.between?(1, 5)
    end
  end

  def notify_interviewer(round, kind)
    return unless round.interviewer&.email.present?

    InterviewMailer
      .with(round: round, to: round.interviewer.email)
      .public_send(kind)
      .deliver_later
  rescue StandardError => e
    Rails.logger.warn("[interview_mailer] #{e.class}: #{e.message}")
  end

  def transition!(event, persist_scorecard: false)
    authorize @round, :update?

    @round.transaction do
      if persist_scorecard && params[:interview_round].present?
        attrs = round_params.to_h
        attrs[:competency_scores] = clean_scores(attrs[:competency_scores]) if attrs.key?(:competency_scores)
        @round.assign_attributes(attrs.except(:overall_score))
      end
      @round.public_send("#{event}!")
    end

    flash.now[:notice] = t("interview_rounds.transitioned.#{event}", default: "Статус обновлён")
    render_interviews_panel(@round.job_applicant)
  rescue AASM::InvalidTransition, ActiveRecord::RecordInvalid => e
    redirect_to job_applicant_path(@round.job_applicant_id), alert: e.message
  end

  # Возвращает Turbo Stream, обновляющий панель интервью + блок stage-actions
  # (на случай авто-перехода applied/screening → interview).
  # Для не-Turbo запросов (curl, тесты) — обычный redirect.
  def render_interviews_panel(applicant)
    applicant.reload
    interviews = applicant.interview_rounds.kept.includes(:interviewer, :created_by).order(scheduled_at: :desc)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("interviews-panel",
                              partial: "interview_rounds/panel_body",
                              locals:  { applicant: applicant, interviews: interviews }),
          turbo_stream.update("applicant-stage-actions",
                              partial: "job_applicants/stage_actions",
                              locals:  { applicant: applicant })
        ]
      end
      format.html { redirect_to job_applicant_path(applicant, anchor: "interviews"), notice: flash.now[:notice] }
    end
  end
end
