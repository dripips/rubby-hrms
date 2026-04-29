class JobOpening < ApplicationRecord
  include Discard::Model
  include Auditable

  belongs_to :company
  belongs_to :department, optional: true
  belongs_to :position,   optional: true
  belongs_to :grade,      optional: true
  belongs_to :owner,      class_name: "User", optional: true

  has_many :job_applicants, dependent: :nullify

  enum :state, { draft: 0, open: 1, on_hold: 2, closed: 3 }, prefix: :state

  validates :title, presence: true
  validates :code, uniqueness: { scope: :company_id, allow_blank: true }
  validates :openings_count, numericality: { greater_than: 0 }

  scope :active,    -> { kept }
  scope :listed,    -> { kept.where(state: %i[open on_hold]) }
  scope :published, -> { kept.where(state: :open).where("published_at IS NULL OR published_at <= ?", Date.current) }

  def applicants_count(stage: nil)
    scope = job_applicants.kept
    stage ? scope.where(stage: stage).count : scope.count
  end

  def funnel
    base = job_applicants.kept.group(:stage).count
    JobApplicant::STAGES.index_with { |s| base[s] || 0 }
  end

  def salary_range
    return nil if salary_from.blank? && salary_to.blank?

    [ salary_from, salary_to ].compact.map { |v| v.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse }.join(" – ") + " #{currency}"
  end
end
