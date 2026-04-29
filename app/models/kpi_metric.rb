class KpiMetric < ApplicationRecord
  include Discard::Model
  include Auditable

  belongs_to :company
  has_many   :kpi_assignments, dependent: :destroy

  enum :target_direction, { maximize: 0, minimize: 1, target: 2 }, prefix: true

  validates :name, :code, presence: true
  validates :code, uniqueness: { scope: :company_id }

  scope :active, -> { kept.where(active: true) }
end
