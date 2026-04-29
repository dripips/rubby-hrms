class RecruitmentCalendarController < ApplicationController
  def index
    authorize InterviewRound, :index?

    @interviewers = User.kept.where(role: %i[hr superadmin manager]).order(:email)
    @kinds        = InterviewRound::KINDS
    @states       = InterviewRound::STATES

    # Агенда — следующие 30 дней, сортируется на клиенте Stimulus
    @upcoming = filtered_rounds
                  .where(scheduled_at: Time.current..30.days.from_now)
                  .order(:scheduled_at)
                  .limit(50)
  end

  # JSON-эндпоинт для FullCalendar — отдаёт события в диапазоне ?start=...&end=...
  def events
    authorize InterviewRound, :index?

    range_start = parse_time(params[:start]) || 30.days.ago
    range_end   = parse_time(params[:end])   || 30.days.from_now

    rounds = filtered_rounds.where(scheduled_at: range_start..range_end)
    render json: rounds.map { |r| calendar_event(r) }
  end

  private

  def filtered_rounds
    scope = InterviewRound.kept
                          .includes(:job_applicant, :interviewer, job_applicant: :job_opening)

    scope = scope.where(interviewer_id: params[:interviewer_id]) if params[:interviewer_id].present?
    scope = scope.where(kind:           params[:kind])           if params[:kind].present?
    scope = scope.where(state:          params[:state])          if params[:state].present?
    scope
  end

  def parse_time(value)
    return nil if value.blank?
    Time.zone.parse(value.to_s) rescue nil
  end

  STATE_COLORS = {
    "scheduled"   => { fg: "#0A84FF", tint: "rgba(10,132,255,0.14)" },
    "in_progress" => { fg: "#5E5CE6", tint: "rgba(94,92,230,0.14)" },
    "completed"   => { fg: "#34C759", tint: "rgba(52,199,89,0.14)"  },
    "cancelled"   => { fg: "#8E8E93", tint: "rgba(142,142,147,0.18)" },
    "no_show"     => { fg: "#FF453A", tint: "rgba(255,69,58,0.14)"  }
  }.freeze

  def calendar_event(r)
    palette = STATE_COLORS[r.state] || STATE_COLORS["scheduled"]
    color   = palette[:fg]
    tint    = palette[:tint]

    applicant = r.job_applicant
    helpers   = Rails.application.routes.url_helpers

    {
      id:    r.id,
      title: "#{r.kind_label}: #{applicant&.full_name}",
      start: r.scheduled_at.iso8601,
      end:   (r.scheduled_at + r.duration_minutes.minutes).iso8601,
      url:   helpers.job_applicant_path(r.job_applicant_id, locale: I18n.locale, anchor: "interviews"),
      backgroundColor: color,
      borderColor:     color,
      extendedProps: {
        kind:           r.kind,
        kind_label:     r.kind_label,
        state:          r.state,
        state_label:    I18n.t("interview_rounds.states.#{r.state}"),
        tint_color:     tint,
        interviewer:    r.interviewer&.display_name,
        interviewer_email: r.interviewer&.email,
        candidate:      applicant&.full_name,
        candidate_initials: applicant&.initials,
        avatar_url:     applicant&.avatar_url,
        opening:        applicant&.job_opening&.title,
        location:       r.location,
        meeting_url:    r.meeting_url,
        score:          r.overall_score,
        recommendation: r.recommendation,
        duration:       r.duration_minutes
      }
    }
  end
end
