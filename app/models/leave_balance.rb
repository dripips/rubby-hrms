class LeaveBalance < ApplicationRecord
  belongs_to :employee
  belongs_to :leave_type

  validates :year, presence: true,
                   numericality: { greater_than: 2000, less_than: 2100 },
                   uniqueness: { scope: %i[employee_id leave_type_id] }

  def remaining_days
    accrued_days + carried_over_days - used_days
  end
end
