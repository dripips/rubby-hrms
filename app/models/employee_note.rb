class EmployeeNote < ApplicationRecord
  include Discard::Model
  include Auditable

  belongs_to :employee
  belongs_to :author, class_name: "User"

  validates :body, presence: true

  scope :visible_for, ->(user) {
    if user.role_superadmin? || user.role_hr?
      kept
    else
      kept.where(hr_only: false)
    end
  }
  scope :ordered, -> { order(pinned: :desc, created_at: :desc) }
end
