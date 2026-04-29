# Default leave-approval rules. Idempotent.
# Creates a "fallback" rule (priority 999, no conditions, manager → HR chain)
# plus a few illustrative rules to showcase the engine.

company = Company.kept.first || raise("Company missing — run db:seed first")

defaults = [
  {
    name:          "Sick leave under 3 days — auto-approve",
    leave_type:    LeaveType.find_by(company: company, code: "SICK"),
    max_days:      3,
    auto_approve:  true,
    approval_chain: [],
    priority:      10
  },
  {
    name:          "Annual leave > 14 days — manager → HR → CEO",
    leave_type:    LeaveType.find_by(company: company, code: "ANNUAL"),
    min_days:      15,
    auto_approve:  false,
    approval_chain: [
      { "kind" => "role", "value" => "manager" },
      { "kind" => "role", "value" => "hr" },
      { "kind" => "role", "value" => "ceo" }
    ],
    priority:      30
  },
  {
    name:          "Default — manager + HR",
    leave_type:    nil,
    auto_approve:  false,
    approval_chain: [
      { "kind" => "role", "value" => "manager" },
      { "kind" => "role", "value" => "hr" }
    ],
    priority:      999
  }
]

defaults.each do |attrs|
  rule = LeaveApprovalRule.kept.find_or_initialize_by(company: company, name: attrs[:name])
  rule.assign_attributes(attrs.merge(active: true))
  rule.save!
end

puts "[seed] leave_approval_rules: total=#{LeaveApprovalRule.kept.where(company: company).count}"
