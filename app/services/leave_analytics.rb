# Aggregates company-wide leave metrics for the HR analytics view.
#   stats           - top-line counters
#   not_taken       - employees with 0 annual leave taken this year
#   top_users       - employees ranked by approved days taken this year
#   type_breakdown  - days taken per leave_type
#   on_leave_now    - currently on leave
#   upcoming        - approved future leaves
#   monthly         - days taken per month (Jan..Dec) of current year
class LeaveAnalytics
  def initialize(company:, year: Date.current.year)
    @company = company
    @year    = year
    @from    = Date.new(year, 1, 1)
    @to      = Date.new(year, 12, 31)
  end

  # ── Top-line KPI ──────────────────────────────────────────────────────────
  def stats
    {
      pending:     LeaveRequest.kept.where(employee: company_employees, state: %w[submitted manager_approved]).count,
      on_leave:    on_leave_now_scope.count,
      upcoming:    upcoming_scope.count,
      avg_days:    avg_days_per_employee.round(1),
      not_taken:   not_taken_employees.size
    }
  end

  # ── Employees without annual leave this year ─────────────────────────────
  # Returns Employee records (with department) sorted by hired_at descending.
  def not_taken_employees(limit: 30)
    annual = LeaveType.where(company: @company, code: "ANNUAL").pick(:id)
    return [] unless annual

    used_emp_ids = LeaveRequest.kept
                     .where(leave_type_id: annual, state: %w[hr_approved active completed])
                     .where("EXTRACT(YEAR FROM started_on) = ?", @year)
                     .distinct.pluck(:employee_id)

    company_employees
      .where.not(id: used_emp_ids)
      .where("hired_at <= ?", @to)
      .includes(:department, :position)
      .order(hired_at: :asc)
      .limit(limit)
  end

  # ── Top users by days taken ──────────────────────────────────────────────
  def top_users(limit: 5)
    rows = LeaveRequest.kept
             .joins(:employee)
             .where(employee_id: company_employees.select(:id))
             .where(state: %w[hr_approved active completed])
             .where("EXTRACT(YEAR FROM started_on) = ?", @year)
             .group("employees.id", "employees.first_name", "employees.last_name")
             .sum(:days)

    rows.sort_by { |_, days| -days }.first(limit).map do |(emp_id, first, last), days|
      employee = Employee.find_by(id: emp_id)
      { employee: employee, full_name: "#{last} #{first}", days: days.to_i }
    end
  end

  # ── Distribution per leave type ──────────────────────────────────────────
  def type_breakdown
    LeaveType.active.where(company: @company).map do |type|
      days = LeaveRequest.kept
               .where(leave_type: type, employee: company_employees)
               .where(state: %w[hr_approved active completed])
               .where("EXTRACT(YEAR FROM started_on) = ?", @year)
               .sum(:days).to_i
      requests = LeaveRequest.kept
                   .where(leave_type: type, employee: company_employees)
                   .where("EXTRACT(YEAR FROM started_on) = ?", @year)
                   .count
      { type: type, days: days, requests: requests }
    end.sort_by { |row| -row[:days] }
  end

  def on_leave_now(limit: 10)
    on_leave_now_scope.includes(:employee, :leave_type).order(:ended_on).limit(limit)
  end

  def upcoming(limit: 10)
    upcoming_scope.includes(:employee, :leave_type).order(:started_on).limit(limit)
  end

  # ── Burnout risk: low KPI + no recent annual leave ───────────────────────
  # Returns array of { employee:, last_leave_at:, days_since_leave:, avg_kpi:, reason: }
  # Reason buckets:
  #   :no_leave_long  — no annual leave taken in 6+ months
  #   :low_kpi        — avg KPI < 60% over last 4 weeks
  #   :both           — both conditions above
  def burnout_at_risk(limit: 10, kpi_threshold: 60.0, no_leave_months: 6)
    cutoff_date = no_leave_months.months.ago.to_date
    annual_id   = LeaveType.where(company: @company, code: "ANNUAL").pick(:id)

    # Last annual leave per employee.
    last_leaves = LeaveRequest.kept
                    .where(leave_type_id: annual_id, state: %w[hr_approved active completed])
                    .where(employee: company_employees)
                    .group(:employee_id)
                    .maximum(:started_on)

    # Avg KPI score per employee over last 4 weeks.
    kpi_avgs = KpiEvaluation.joins(:kpi_assignment)
                 .where(kpi_assignments: { period_start: 4.weeks.ago.. })
                 .group("kpi_assignments.employee_id")
                 .average(:score)

    rows = []
    company_employees.includes(:department, :position).find_each do |emp|
      last_leave = last_leaves[emp.id]
      kpi        = kpi_avgs[emp.id]&.to_f

      no_leave   = last_leave.nil? || last_leave < cutoff_date
      low_kpi    = kpi.present? && kpi < kpi_threshold

      next unless no_leave || low_kpi

      reason = if no_leave && low_kpi then :both
      elsif no_leave         then :no_leave_long
      else                        :low_kpi
      end

      rows << {
        employee:         emp,
        last_leave_at:    last_leave,
        days_since_leave: last_leave ? (Date.current - last_leave).to_i : nil,
        avg_kpi:          kpi&.round(0),
        reason:           reason
      }
    end

    # Sort by severity: both > no_leave > low_kpi; then by days_since_leave desc
    severity_score = { both: 0, no_leave_long: 1, low_kpi: 2 }
    rows.sort_by { |r| [ severity_score[r[:reason]], -(r[:days_since_leave] || 9_999) ] }.first(limit)
  end

  # ── Days taken per calendar month of current year ────────────────────────
  def monthly
    # Postgres EXTRACT returns numeric (BigDecimal in Rails), so the keys
    # in the grouped hash don't match Integer 1..12. Cast to int explicitly
    # via Arel and normalize keys, otherwise rows[m] always returns nil.
    rows = LeaveRequest.kept
             .where(employee: company_employees)
             .where(state: %w[hr_approved active completed])
             .where("EXTRACT(YEAR FROM started_on) = ?", @year)
             .group(Arel.sql("EXTRACT(MONTH FROM started_on)::int"))
             .sum(:days)
             .transform_keys(&:to_i)

    (1..12).map { |m| { month: m, days: rows[m].to_i } }
  end

  private

  def company_employees
    Employee.kept.where(company: @company)
  end

  def on_leave_now_scope
    LeaveRequest.kept
      .where(employee: company_employees, state: %w[hr_approved active])
      .where("started_on <= ? AND ended_on >= ?", Date.current, Date.current)
  end

  def upcoming_scope
    LeaveRequest.kept
      .where(employee: company_employees, state: %w[hr_approved])
      .where("started_on > ?", Date.current)
  end

  def avg_days_per_employee
    total_employees = company_employees.count
    return 0.0 if total_employees.zero?
    days_taken = LeaveRequest.kept
                   .where(employee: company_employees, state: %w[hr_approved active completed])
                   .where("EXTRACT(YEAR FROM started_on) = ?", @year)
                   .sum(:days).to_f
    days_taken / total_employees
  end
end
