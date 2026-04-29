class KpiEvaluation < ApplicationRecord
  include Auditable

  belongs_to :kpi_assignment
  belongs_to :evaluator, class_name: "User"

  validates :evaluated_at, presence: true
  validates :score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
end
