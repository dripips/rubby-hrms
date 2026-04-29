class LeaveRequest < ApplicationRecord
  include Discard::Model
  include Auditable
  include AASM

  belongs_to :employee
  belongs_to :leave_type
  has_many :leave_approvals, dependent: :destroy

  validates :started_on, :ended_on, :days, presence: true
  validate  :end_after_start

  scope :pending,    -> { kept.where(state: %w[submitted manager_approved]) }
  scope :upcoming,   -> { kept.where("started_on >= ?", Date.current).order(:started_on) }
  scope :overlapping, ->(from, to) { kept.where("started_on <= ? AND ended_on >= ?", to, from) }

  aasm column: :state, whiny_persistence: true do
    state :draft, initial: true
    state :submitted
    state :manager_approved
    state :hr_approved
    state :active
    state :completed
    state :rejected
    state :cancelled

    event :submit do
      transitions from: :draft, to: :submitted, after: -> {
        update_column(:applied_at, Time.current)
        # If the configured chain is empty (auto-approve rule matched) jump
        # straight to hr_approved so the request is ready for activation.
        result = LeaveApprovalEngine.new(self).call
        update_column(:state, "hr_approved") if result[:auto_approve]
      }
    end
    event :approve_by_manager do
      transitions from: :submitted, to: :manager_approved
    end
    event :approve_by_hr do
      transitions from: :manager_approved, to: :hr_approved
    end
    event :start do
      transitions from: :hr_approved, to: :active
    end
    event :complete do
      transitions from: :active, to: :completed
    end
    event :reject do
      transitions from: %i[submitted manager_approved], to: :rejected
    end
    event :cancel do
      transitions from: %i[draft submitted manager_approved], to: :cancelled
    end
    # Power-user shortcut: superadmin / general director can finalize any
    # pending request in a single click without going through manager → HR.
    event :force_approve do
      transitions from: %i[submitted manager_approved], to: :hr_approved
    end
  end

  private

  def end_after_start
    return if started_on.blank? || ended_on.blank?

    errors.add(:ended_on, :invalid) if ended_on < started_on
  end
end
