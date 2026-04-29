# Configurable approval rule. Engine picks the first matching active rule
# (lowest priority number) for a given LeaveRequest and uses its chain.
class LeaveApprovalRule < ApplicationRecord
  include Discard::Model
  include Auditable

  STEP_KINDS  = %w[role user].freeze
  STEP_ROLES  = %w[manager hr ceo department_head].freeze

  belongs_to :company
  belongs_to :leave_type, optional: true
  belongs_to :department, optional: true
  belongs_to :min_grade,  class_name: "Grade", optional: true

  validates :name, presence: true
  validate  :validate_chain
  validate  :min_days_lte_max_days

  scope :ordered_active, -> { kept.where(active: true).order(:priority, :id) }

  # Returns true if this rule applies to the given leave request.
  def matches?(leave_request)
    return false unless active? && !discarded?
    return false if leave_type_id && leave_type_id != leave_request.leave_type_id
    return false if department_id && department_id != leave_request.employee&.department_id
    return false if min_days     && leave_request.days.to_i < min_days
    return false if max_days     && leave_request.days.to_i > max_days
    return false if min_grade_id && (leave_request.employee&.grade&.level || 0) < (min_grade.level || 0)
    true
  end

  def auto_approve? = !!auto_approve

  def steps
    Array(approval_chain).map { |s| s.is_a?(Hash) ? s : {} }
  end

  private

  def validate_chain
    chain = Array(approval_chain)
    chain.each_with_index do |step, idx|
      kind  = step.is_a?(Hash) ? (step["kind"] || step[:kind]).to_s : nil
      value = step.is_a?(Hash) ? (step["value"] || step[:value])    : nil
      unless STEP_KINDS.include?(kind)
        errors.add(:approval_chain, "step #{idx + 1}: invalid kind #{kind.inspect}")
        next
      end
      if kind == "role" && !STEP_ROLES.include?(value.to_s)
        errors.add(:approval_chain, "step #{idx + 1}: invalid role #{value.inspect}")
      end
      if kind == "user" && value.to_s !~ /\A\d+\z/
        errors.add(:approval_chain, "step #{idx + 1}: user step requires integer id")
      end
    end
  end

  def min_days_lte_max_days
    return if min_days.blank? || max_days.blank?
    errors.add(:max_days, :must_be_gte_min_days) if max_days < min_days
  end
end
