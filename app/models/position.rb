class Position < ApplicationRecord
  include Discard::Model

  belongs_to :company
  has_many   :employees, dependent: :nullify

  validates :name, presence: true
  validates :code, uniqueness: { scope: :company_id, allow_blank: true }

  scope :active, -> { kept.where(active: true).order(:sort_order, :name) }
end
