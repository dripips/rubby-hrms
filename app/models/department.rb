class Department < ApplicationRecord
  include Discard::Model
  include Auditable

  has_closure_tree order: "sort_order", dependent: :destroy

  belongs_to :company
  belongs_to :head, class_name: "Employee", foreign_key: :head_employee_id, optional: true
  has_many   :employees, dependent: :nullify

  validates :name, presence: true
  validates :code, uniqueness: { scope: :company_id, allow_blank: true }

  scope :active, -> { kept }

  def full_path
    self_and_ancestors.reverse.map(&:name).join(" / ")
  end
end
