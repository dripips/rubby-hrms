class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @greeting = greeting_by_hour
    @company  = current_company

    @kpi_tiles       = build_kpi_tiles
    @recent_activity = recent_activity
    @upcoming        = upcoming_events
  end

  # Страница настройки виджетов: drag-drop reorder + hide/show.
  def customize
    @widgets = DashboardWidgets.catalog_for_user(current_user)
  end

  # POST: { order: [...], hidden: [...], sizes: { key => "s|m|l" } }
  def update_widgets
    DashboardWidgets.save_preferences!(current_user,
                                       order:  params[:order],
                                       hidden: params[:hidden],
                                       sizes:  params[:sizes])
    redirect_to dashboard_path, notice: t("dashboard.preferences_saved", default: "Дашборд настроен")
  end

  def reset_widgets
    DashboardWidgets.reset!(current_user)
    redirect_to customize_dashboard_path, notice: t("dashboard.preferences_reset", default: "Сброшено к дефолту")
  end

  private

  def greeting_by_hour
    hour = Time.current.in_time_zone(current_user.time_zone).hour
    case hour
    when 5..11  then t("dashboard.greetings.morning")
    when 12..17 then t("dashboard.greetings.afternoon")
    when 18..22 then t("dashboard.greetings.evening")
    else             t("dashboard.greetings.night")
    end
  end

  def build_kpi_tiles
    [
      {
        label: t("dashboard.tiles.active_employees"),
        value: Employee.kept.state_active.count,
        delta: "+#{Employee.kept.where(hired_at: 30.days.ago..Date.current).count}",
        up: true, tone: "blue"
      },
      {
        label: t("dashboard.tiles.on_leave_today"),
        value: leave_today_count,
        delta: "—",
        up: true, tone: "orange"
      },
      {
        label: t("dashboard.tiles.open_positions"),
        value: Position.active.count,
        delta: "—",
        up: false, tone: "purple"
      },
      {
        label: t("dashboard.tiles.weekly_kpi_avg"),
        value: weekly_kpi_avg,
        delta: "—",
        up: true, tone: "green"
      }
    ]
  end

  def leave_today_count
    LeaveRequest.kept.where(state: "active")
                .where("started_on <= ? AND ended_on >= ?", Date.current, Date.current)
                .count
  end

  def weekly_kpi_avg
    avg = KpiEvaluation
            .joins(:kpi_assignment)
            .where(kpi_assignments: { period_start: 1.week.ago.to_date.. })
            .average(:score)
    avg ? "#{avg.round(0)}%" : "—"
  end

  def recent_activity
    Employee.kept.order(updated_at: :desc).limit(5).map do |e|
      {
        who:      e.full_name,
        what:     activity_text(e),
        when_at:  e.updated_at,
        tone:     activity_tone(e),
        initials: e.initials
      }
    end
  end

  def activity_text(emp)
    case emp.state
    when "probation" then t("dashboard.activity.completed_onboarding")
    when "on_leave"  then t("dashboard.activity.requested_leave")
    when "active"    then t("dashboard.activity.kpi_updated", default: "Активен")
    else                  t("dashboard.activity.document_uploaded")
    end
  end

  def activity_tone(emp)
    case emp.state
    when "probation" then "orange"
    when "on_leave"  then "purple"
    when "active"    then "green"
    else                  "blue"
    end
  end

  def upcoming_events
    events = []

    Employee.kept.where.not(birth_date: nil).find_each do |e|
      next unless e.birth_date

      this_year  = e.birth_date.change(year: Date.current.year)
      next_birth = this_year >= Date.current ? this_year : this_year.next_year
      next unless next_birth - Date.current <= 14

      events << {
        date: next_birth,
        name: e.short_name.presence || e.full_name,
        tag:  t("dashboard.upcoming.birthday")
      }
    end

    events.sort_by { |e| e[:date] }.first(5)
  end
end
