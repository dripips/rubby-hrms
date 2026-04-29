class LeaveType < ApplicationRecord
  include Discard::Model

  belongs_to :company
  has_many   :leave_requests, dependent: :destroy
  has_many   :leave_balances, dependent: :destroy

  validates :name, :code, presence: true
  validates :code, uniqueness: { scope: :company_id }

  scope :active, -> { kept.where(active: true).order(:sort_order, :name) }
end
