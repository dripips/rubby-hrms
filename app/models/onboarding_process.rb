class OnboardingProcess < ApplicationRecord
  include Discard::Model
  include Auditable
  include AASM

  STATES = %w[draft active completed cancelled].freeze

  belongs_to :employee
  belongs_to :template,   class_name: "ProcessTemplate", optional: true
  belongs_to :mentor,     class_name: "Employee",        optional: true
  belongs_to :created_by, class_name: "User",            optional: true

  has_many :tasks, -> { order(:position, :id) }, class_name: "OnboardingTask", dependent: :destroy
  has_many :ai_runs, dependent: :nullify

  validates :state, inclusion: { in: STATES }

  scope :active_only, -> { kept.where(state: "active") }
  scope :recent,      -> { kept.order(created_at: :desc) }

  aasm column: :state, whiny_persistence: true do
    state :draft, initial: true
    state :active
    state :completed
    state :cancelled

    event :activate do
      transitions from: :draft, to: :active, after: -> { self.started_on ||= Date.current }
    end

    event :complete do
      transitions from: :active, to: :completed, after: -> { self.completed_at = Time.current }
    end

    event :cancel do
      transitions from: %i[draft active], to: :cancelled
    end
  end

  def progress_percent
    total = tasks.count
    return 0 if total.zero?

    done = tasks.where(state: %w[done skipped]).count
    ((done.to_f / total) * 100).round
  end

  def overdue_tasks
    tasks.where(state: %w[pending in_progress]).where("due_on < ?", Date.current)
  end

  def materialize_from_template!
    return if template.blank? || tasks.exists?

    base_date = started_on || Date.current
    template.items_array.each_with_index do |item, idx|
      offset = item["due_offset_days"].to_i
      tasks.create!(
        title:       item["title"].to_s,
        description: item["description"],
        kind:        (item["kind"].presence || "general"),
        position:    item["position"].to_i.nonzero? || idx,
        due_on:      offset.zero? ? nil : base_date + offset.days
      )
    end
  end
end
