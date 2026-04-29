class InterviewRound < ApplicationRecord
  include Discard::Model
  include Auditable
  include AASM

  KINDS = %w[hr tech cultural final].freeze
  STATES = %w[scheduled in_progress completed cancelled no_show].freeze
  RECOMMENDATIONS = %w[strong_no no maybe yes strong_yes].freeze

  # Каждый тип интервью имеет свой набор компетенций. Скоринг 1..5.
  COMPETENCY_TEMPLATES = {
    "hr"       => %w[communication motivation culture_fit reliability],
    "tech"     => %w[technical_depth problem_solving system_design code_quality],
    "cultural" => %w[teamwork ownership growth_mindset feedback],
    "final"    => %w[overall_impression risk_assessment compensation_fit]
  }.freeze

  RECOMMENDATION_TONES = {
    "strong_yes" => "success", "yes" => "success",
    "maybe" => "warning",
    "no" => "danger", "strong_no" => "danger"
  }.freeze

  belongs_to :job_applicant
  belongs_to :interviewer, class_name: "User", optional: true
  belongs_to :created_by,  class_name: "User"

  validates :kind, inclusion: { in: KINDS }
  validates :state, inclusion: { in: STATES }
  validates :recommendation, inclusion: { in: RECOMMENDATIONS, allow_blank: true }
  validates :scheduled_at, presence: true
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  validate  :scores_within_range
  validate  :scores_keys_match_template

  scope :upcoming, -> { kept.where(state: %w[scheduled]).where("scheduled_at >= ?", Time.current).order(:scheduled_at) }
  scope :recent,   -> { kept.order(scheduled_at: :desc) }

  aasm column: :state, whiny_persistence: true do
    state :scheduled, initial: true
    state :in_progress
    state :completed
    state :cancelled
    state :no_show

    event :start do
      transitions from: :scheduled, to: :in_progress, after: -> { self.started_at = Time.current }
    end

    event :complete do
      transitions from: %i[scheduled in_progress], to: :completed,
                  after: -> { self.completed_at = Time.current; self.overall_score = calculate_overall_score }
    end

    event :cancel do
      transitions from: %i[scheduled in_progress], to: :cancelled
    end

    event :mark_no_show do
      transitions from: :scheduled, to: :no_show
    end

    event :reopen do
      transitions from: %i[completed cancelled no_show], to: :scheduled
    end
  end

  def competencies
    COMPETENCY_TEMPLATES[kind] || []
  end

  def score_for(competency)
    competency_scores[competency.to_s].to_i
  end

  def calculate_overall_score
    values = competencies.map { |c| score_for(c) }.reject(&:zero?)
    return nil if values.empty?

    # 1..5 → 0..100 для обзорного score (соответствует JobApplicant.overall_score).
    avg = values.sum.to_f / values.size
    ((avg - 1) / 4.0 * 100).round
  end

  def recommendation_tone
    RECOMMENDATION_TONES[recommendation] || "neutral"
  end

  def kind_label
    I18n.t("interview_rounds.kinds.#{kind}", default: kind.humanize)
  end

  def state_label
    I18n.t("interview_rounds.states.#{state}", default: state.humanize)
  end

  def recommendation_label
    return nil if recommendation.blank?

    I18n.t("interview_rounds.recommendations.#{recommendation}", default: recommendation.humanize)
  end

  def scheduled?     = state == "scheduled"
  def editable?      = !%w[completed cancelled].include?(state)
  def has_scorecard? = competency_scores.any? { |_, v| v.to_i.positive? }

  private

  def scores_within_range
    return if competency_scores.blank?

    competency_scores.each do |k, v|
      next if v.blank?

      n = v.to_i
      errors.add(:competency_scores, "#{k} must be between 1 and 5") unless (1..5).cover?(n)
    end
  end

  def scores_keys_match_template
    return if competency_scores.blank?

    allowed = competencies + [ "" ]
    extras = competency_scores.keys.map(&:to_s) - allowed
    errors.add(:competency_scores, "unknown keys: #{extras.join(', ')}") if extras.any?
  end
end
