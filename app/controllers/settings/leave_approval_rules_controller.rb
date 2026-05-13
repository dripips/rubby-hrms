class Settings::LeaveApprovalRulesController < SettingsController
  before_action :set_company
  before_action :set_rule, only: %i[edit update destroy]

  def index
    @rules    = LeaveApprovalRule.kept.where(company: @company).order(:priority, :id)
    @new_rule = LeaveApprovalRule.new(company: @company, priority: next_priority, active: true, approval_chain: [
      { "kind" => "role", "value" => "manager" },
      { "kind" => "role", "value" => "hr" }
    ])
    load_form_options
    @config = LeavesSettings.for(@company)
  end

  def new
    @rule = LeaveApprovalRule.new(company: @company, priority: next_priority, active: true)
    load_form_options
  end

  def create
    @rule = LeaveApprovalRule.new(rule_params.merge(company: @company))
    @rule.approval_chain = parse_chain(params.dig(:leave_approval_rule, :chain_steps))

    if @rule.save
      redirect_to settings_leave_approval_rules_path, notice: t("settings.leaves.rule.created")
    else
      redirect_to settings_leave_approval_rules_path, alert: @rule.errors.full_messages.to_sentence
    end
  end

  def edit
    load_form_options
  end

  def update
    @rule.assign_attributes(rule_params)
    if (raw = params.dig(:leave_approval_rule, :chain_steps)).present?
      @rule.approval_chain = parse_chain(raw)
    end

    if @rule.save
      redirect_to settings_leave_approval_rules_path, notice: t("settings.leaves.rule.updated")
    else
      redirect_to settings_leave_approval_rules_path, alert: @rule.errors.full_messages.to_sentence
    end
  end

  def destroy
    @rule.discard
    redirect_to settings_leave_approval_rules_path, notice: t("settings.leaves.rule.deleted")
  end

  private

  def set_company
    @company = current_company
  end

  def set_rule
    @rule = LeaveApprovalRule.kept.where(company: @company).find(params[:id])
  end

  def load_form_options
    @leave_types = LeaveType.active.where(company: @company)
    @departments = Department.kept.where(company: @company).order(:name)
    @grades      = Grade.active.where(company: @company)
    @users       = User.kept.includes(:employee).order(:email)
  end

  def next_priority
    (LeaveApprovalRule.kept.where(company: @company).maximum(:priority) || 0) + 10
  end

  def rule_params
    params.require(:leave_approval_rule).permit(
      :name, :description, :leave_type_id, :department_id, :min_grade_id,
      :min_days, :max_days, :auto_approve, :priority, :active
    )
  end

  # chain_steps comes from the form as ordered array of strings:
  #   ["role:manager", "role:hr", "user:17", "role:ceo"]
  def parse_chain(raw)
    Array(raw).map(&:to_s).reject(&:blank?).map do |entry|
      kind, value = entry.split(":", 2)
      next nil unless %w[role user].include?(kind) && value.present?
      { "kind" => kind, "value" => kind == "user" ? value.to_i : value.to_s }
    end.compact
  end
end
