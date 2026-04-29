class OffboardingProcess < ApplicationRecord
  include Discard::Model
  include Auditable
  include AASM

  STATES  = %w[draft active completed cancelled].freeze
  REASONS = %w[voluntary involuntary retirement contract_end].freeze

  belongs_to :employee
  belongs_to :template,   class_name: "ProcessTemplate", optional: true
  belongs_to :created_by, class_name: "User",            optional: true

  has_many :tasks, -> { order(:position, :id) }, class_name: "OffboardingTask", dependent: :destroy
  has_many :ai_runs, dependent: :nullify

  validates :state,  inclusion: { in: STATES }
  validates :reason, inclusion: { in: REASONS }

  scope :active_only, -> { kept.where(state: "active") }
  scope :recent,      -> { kept.order(created_at: :desc) }

  aasm column: :state, whiny_persistence: true do
    state :draft, initial: true
    state :active
    state :completed
    state :cancelled

    event :activate do
      transitions from: :draft, to: :active
    end

    event :complete do
      transitions from: :active, to: :completed, after: :on_complete!
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

    base_date = last_day || Date.current + 14.days
    template.items_array.each_with_index do |item, idx|
      offset = item["due_offset_days"].to_i
      tasks.create!(
        title:       item["title"].to_s,
        description: item["description"],
        kind:        (item["kind"].presence || "general"),
        position:    item["position"].to_i.nonzero? || idx,
        due_on:      offset.zero? ? nil : base_date - offset.days
      )
    end
  end

  private

  # При завершении офбординга помечаем сотрудника как `terminated` —
  # это удобно для KPI-отчётов и leave-аналитики.
  def on_complete!
    self.completed_at = Time.current
    employee.update_columns(state: Employee.states[:terminated], discarded_at: Time.current)
  end
end
