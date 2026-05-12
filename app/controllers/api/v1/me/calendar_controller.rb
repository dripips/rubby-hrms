# /api/v1/me/calendar.ics — Bearer-auth iCalendar feed для подписки в Google
# Calendar / Outlook / Apple Calendar / любого CalDAV-клиента.
#
# Отличается от /recruitment/calendar.ics (web-сессия, для скачивания) —
# здесь Bearer-токен в Authorization header или ?api_key=... param чтобы
# Google Calendar мог подписаться (он не умеет header'ы).
class Api::V1::Me::CalendarController < Api::V1::BaseController
  # Override auth — Google Calendar не умеет посылать Authorization header.
  # Поддерживаем ?token=hrms_xxx_yyy query-param как fallback.
  skip_before_action :authenticate_api_user!
  before_action :authenticate_via_token_or_header!

  def show
    builder = IcalendarBuilder.new(prod_id: "HRMS My Calendar")

    # Интервью в которых юзер — interviewer + applicant
    rounds = InterviewRound.kept
                           .includes(:job_applicant, job_applicant: :job_opening)
                           .where(interviewer_id: current_user.id)
                           .where(scheduled_at: 30.days.ago..180.days.from_now)
                           .where.not(state: %w[cancelled no_show])

    rounds.find_each do |r|
      applicant = r.job_applicant
      builder.add_event(
        uid:         "interview-#{r.id}@hrms",
        summary:     "#{r.kind_label}: #{applicant&.full_name}",
        start_at:    r.scheduled_at,
        end_at:      r.scheduled_at + r.duration_minutes.minutes,
        description: "Vacancy: #{applicant&.job_opening&.title}\nState: #{I18n.t("interview_rounds.states.#{r.state}")}",
        location:    r.location.presence || r.meeting_url.presence
      )
    end

    # Дни рождения сотрудников (если юзер — HR / superadmin / manager) — следующие 90 дней
    if %w[hr superadmin manager].include?(current_user.role.to_s)
      Employee.kept.where.not(birth_date: nil).find_each do |emp|
        next unless emp.birth_date
        upcoming = next_birthday(emp.birth_date)
        next if upcoming > 90.days.from_now

        builder.add_event(
          uid:      "birthday-#{emp.id}-#{upcoming.year}@hrms",
          summary:  "🎂 #{emp.short_name.presence || emp.full_name}",
          start_at: upcoming.beginning_of_day,
          end_at:   upcoming.end_of_day,
          description: "Birthday reminder"
        )
      end
    end

    send_data builder.to_s,
              type: "text/calendar; charset=utf-8",
              filename: "hrms-#{current_user.email.split('@').first}.ics",
              disposition: "inline"  # Google Calendar парсит inline быстрее
  end

  private

  def authenticate_via_token_or_header!
    raw_token = request.headers["Authorization"].to_s.sub(/\Abearer /i, "").presence ||
                params[:token].to_s.presence

    user = ApiToken.authenticate(raw_token)
    return render(json: { error: "unauthorized" }, status: :unauthorized) unless user
    @current_user = user
  end

  def next_birthday(date)
    today = Date.current
    this_year = date.change(year: today.year)
    this_year >= today ? this_year : this_year.next_year
  end
end
