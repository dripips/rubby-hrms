# Resolves the approval chain for a specific LeaveRequest using
# LeaveApprovalRule (highest-priority match wins). Chain steps are normalized
# into hashes that downstream code can act on:
#   { kind: "role", value: "manager", label: "Direct manager", users: [User…] }
#   { kind: "user", value: 17,        label: "John Doe",       users: [User…] }
class LeaveApprovalEngine
  Step = Struct.new(:kind, :value, :label, :users, keyword_init: true) do
    def role? = kind.to_s == "role"
    def user? = kind.to_s == "user"
    def involves_user?(user) = users.any? { |u| u.id == user&.id }
  end

  def initialize(leave_request)
    @lr = leave_request
  end

  # Returns:
  #   { rule: <LeaveApprovalRule|nil>, auto_approve: bool, steps: [Step…] }
  def call
    rule = match_rule
    if rule.nil?
      return { rule: nil, auto_approve: false, steps: default_steps }
    end
    return { rule: rule, auto_approve: true, steps: [] } if rule.auto_approve?

    { rule: rule, auto_approve: false, steps: rule.steps.map { |s| build_step(s) } }
  end

  # Convenience: returns approver users for the next pending step (first step
  # whose approver hasn't approved yet via LeaveApproval). Useful for UI hints
  # and authorization on /approve actions.
  def next_step
    chain = call[:steps]
    return nil if chain.empty?
    approved_count = @lr.leave_approvals.where(decision: :approved).count
    chain[approved_count]
  end

  private

  def match_rule
    return nil unless @lr.employee && @lr.leave_type
    company_id = @lr.employee.company_id
    LeaveApprovalRule.ordered_active.where(company_id: company_id)
                     .find { |r| r.matches?(@lr) }
  end

  def default_steps
    # No rule configured — fall back to manager → hr.
    [
      build_step({ "kind" => "role", "value" => "manager" }),
      build_step({ "kind" => "role", "value" => "hr" })
    ].compact
  end

  def build_step(spec)
    kind  = (spec["kind"]  || spec[:kind]).to_s
    value = (spec["value"] || spec[:value])

    if kind == "role"
      Step.new(
        kind:  "role",
        value: value.to_s,
        label: I18n.t("leaves.approval_steps.#{value}", default: value.to_s.humanize),
        users: users_for_role(value.to_s)
      )
    else
      u = User.kept.find_by(id: value.to_i)
      Step.new(
        kind:  "user",
        value: value.to_i,
        label: u&.display_name || "User ##{value}",
        users: Array(u)
      )
    end
  end

  def users_for_role(role)
    case role
    when "manager"
      mgr_emp = @lr.employee&.manager
      Array(mgr_emp&.user)
    when "hr"
      User.kept.where(role: User.roles[:hr]).to_a
    when "ceo"
      # CEO = superadmin in this MVP; switch to dedicated role when available.
      User.kept.where(role: User.roles[:superadmin]).to_a
    when "department_head"
      head_emp = @lr.employee&.department&.head_employee
      Array(head_emp&.user)
    else
      []
    end
  end
end
