class Contract < ApplicationRecord
  include Discard::Model

  belongs_to :employee

  enum :kind, { permanent: 0, fixed_term: 1, service_agreement: 2, internship: 3 }, prefix: true

  validates :started_at, presence: true
  validate  :end_after_start

  scope :active, -> { kept.where(active: true) }
  scope :ending_soon, ->(days = 30) {
    kept.where(active: true).where(ended_at: Date.current..(Date.current + days.days))
  }

  private

  def end_after_start
    return if ended_at.blank? || started_at.blank?

    errors.add(:ended_at, :invalid) if ended_at < started_at
  end
end
