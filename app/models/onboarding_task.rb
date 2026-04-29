class OnboardingTask < ApplicationRecord
  include Auditable
  include AASM

  KINDS  = %w[paperwork equipment access training intro checkin general].freeze
  STATES = %w[pending in_progress done skipped].freeze

  belongs_to :onboarding_process, inverse_of: :tasks, touch: true
  belongs_to :assignee, class_name: "User", optional: true

  validates :title, presence: true
  validates :kind,  inclusion: { in: KINDS }
  validates :state, inclusion: { in: STATES }

  scope :pending_only, -> { where(state: %w[pending in_progress]) }
  scope :completed,    -> { where(state: %w[done skipped]) }

  aasm column: :state, whiny_persistence: true do
    state :pending, initial: true
    state :in_progress
    state :done
    state :skipped

    event :start do
      transitions from: :pending, to: :in_progress
    end

    event :complete do
      transitions from: %i[pending in_progress], to: :done,
                  after: -> { self.completed_at = Time.current }
    end

    event :skip do
      transitions from: %i[pending in_progress], to: :skipped
    end

    event :reopen do
      transitions from: %i[done skipped], to: :pending,
                  after: -> { self.completed_at = nil }
    end
  end
end
