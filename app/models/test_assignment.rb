class TestAssignment < ApplicationRecord
  include Discard::Model
  include Auditable
  include AASM

  STATES = %w[sent in_progress submitted reviewed cancelled].freeze

  belongs_to :job_applicant
  belongs_to :created_by,  class_name: "User"
  belongs_to :reviewed_by, class_name: "User", optional: true

  has_many_attached :brief_files       # условия задания
  has_many_attached :submission_files  # работа кандидата

  validates :title, presence: true
  validates :state, inclusion: { in: STATES }
  validates :score, numericality: { only_integer: true, in: 0..100, allow_nil: true }

  scope :active, -> { kept }
  scope :overdue, -> { kept.where(state: %w[sent in_progress]).where("deadline < ?", Time.current) }

  aasm column: :state, whiny_persistence: true do
    state :sent, initial: true
    state :in_progress
    state :submitted
    state :reviewed
    state :cancelled

    event :start         do transitions to: :in_progress end
    event :submit_work   do transitions to: :submitted, after: -> { update_column(:submitted_at, Time.current) } end
    event :review        do transitions to: :reviewed,  after: -> { update_column(:reviewed_at, Time.current) } end
    event :cancel        do transitions to: :cancelled end
    event :reopen        do transitions to: :sent end
  end

  def overdue?
    deadline.present? && deadline < Time.current && %w[sent in_progress].include?(state)
  end

  def status_tone
    case state
    when "sent"        then "info"
    when "in_progress" then "warning"
    when "submitted"   then "purple"
    when "reviewed"    then "success"
    when "cancelled"   then "danger"
    end
  end
end
