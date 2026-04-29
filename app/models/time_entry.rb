class TimeEntry < ApplicationRecord
  belongs_to :employee

  enum :kind, { work: 0, overtime: 1, sick: 2, leave: 3, holiday: 4 }, prefix: true

  validates :date, presence: true, uniqueness: { scope: :employee_id }
  validates :hours, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 24 }
end
