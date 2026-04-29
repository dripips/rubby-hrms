class Company < ApplicationRecord
  include Discard::Model
  include Auditable

  has_many :departments,    dependent: :destroy
  has_many :positions,      dependent: :destroy
  has_many :grades,         dependent: :destroy
  has_many :employees,      dependent: :destroy
  has_many :leave_types,    dependent: :destroy
  has_many :holidays,       dependent: :destroy
  has_many :kpi_metrics,    dependent: :destroy
  has_many :document_types, dependent: :destroy
  has_many :dictionaries,   dependent: :destroy
  has_many :process_templates, dependent: :destroy

  validates :name, presence: true
  validates :inn, length: { in: 10..12 }, allow_blank: true

  scope :active, -> { kept }
end
