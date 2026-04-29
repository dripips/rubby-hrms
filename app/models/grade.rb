class Grade < ApplicationRecord
  include Discard::Model

  belongs_to :company
  has_many   :employees, dependent: :nullify

  validates :name, :level, presence: true
  validates :level, uniqueness: { scope: :company_id }

  scope :active, -> { kept.where(active: true).order(:level) }
end
