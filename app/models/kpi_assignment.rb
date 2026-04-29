class KpiAssignment < ApplicationRecord
  include Auditable

  belongs_to :employee
  belongs_to :kpi_metric
  has_many   :kpi_evaluations, dependent: :destroy

  validates :period_start, :period_end, presence: true
  validate  :period_end_after_start

  scope :for_week,    ->(date) { where(period_start: date.beginning_of_week, period_end: date.end_of_week) }
  scope :overlapping, ->(from, to) { where("period_start <= ? AND period_end >= ?", to, from) }
  scope :ordered_by_period, -> { order(period_start: :desc, id: :desc) }

  def latest_evaluation
    kpi_evaluations.order(evaluated_at: :desc).first
  end

  def period_label
    if period_start.beginning_of_week == period_start && period_end == period_start.end_of_week
      I18n.l(period_start, format: :short) + " – " + I18n.l(period_end, format: :short)
    elsif period_start.day == 1 && period_end == period_start.end_of_month
      I18n.l(period_start, format: "%B %Y")
    else
      I18n.l(period_start, format: :short) + " – " + I18n.l(period_end, format: :short)
    end
  end

  private

  def period_end_after_start
    return if period_start.blank? || period_end.blank?
    errors.add(:period_end, :must_be_after_start) if period_end < period_start
  end
end
