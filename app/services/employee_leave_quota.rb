# Computes per-leave-type quota for an employee in a given year.
# Falls back to LeaveType.default_days_per_year if no LeaveBalance row exists.
# `used` is computed from approved leave requests (hr_approved / active / completed).
class EmployeeLeaveQuota
  Row = Struct.new(:leave_type, :accrued, :used, :remaining, :pending, keyword_init: true)

  def initialize(employee:, year: Date.current.year)
    @employee = employee
    @year     = year
  end

  def rows
    return [] unless @employee
    leave_types = LeaveType.active.where(company_id: @employee.company_id)

    leave_types.map do |type|
      balance  = LeaveBalance.find_by(employee_id: @employee.id, leave_type_id: type.id, year: @year)
      accrued  = balance ? (balance.accrued_days + balance.carried_over_days) : (type.default_days_per_year || 0)
      used     = balance ? balance.used_days : approved_days(type)
      pending  = pending_days(type)

      Row.new(
        leave_type: type,
        accrued:    accrued,
        used:       used,
        pending:    pending,
        remaining:  [ accrued - used, 0 ].max
      )
    end
  end

  private

  def approved_days(type)
    LeaveRequest.kept
      .where(employee_id: @employee.id, leave_type_id: type.id)
      .where(state: %w[hr_approved active completed])
      .where("EXTRACT(YEAR FROM started_on) = ?", @year)
      .sum(:days).to_i
  end

  def pending_days(type)
    LeaveRequest.kept
      .where(employee_id: @employee.id, leave_type_id: type.id)
      .where(state: %w[submitted manager_approved])
      .where("EXTRACT(YEAR FROM started_on) = ?", @year)
      .sum(:days).to_i
  end
end
