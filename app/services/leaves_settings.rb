# Reads / writes the company-wide leave workflow configuration stored in
# AppSetting(category: "leaves").data. Provides safe defaults so the rest
# of the app can call `LeavesSettings.for(company).chain` even when nothing
# was configured yet.
class LeavesSettings
  AVAILABLE_STEPS = %w[manager hr ceo].freeze

  DEFAULTS = {
    "chain"                  => %w[manager hr],
    "auto_approve_below_days"=> 0,
    "manager_can_quick"      => true,
    "ceo_can_force_approve"  => true,
    "require_doc_for_sick"   => false
  }.freeze

  def self.for(company)
    new(company)
  end

  def initialize(company)
    @company = company
    @setting = AppSetting.fetch(company: company, category: "leaves")
  end

  def chain
    raw = @setting.get("chain").presence || DEFAULTS["chain"]
    Array(raw).map(&:to_s).select { |s| AVAILABLE_STEPS.include?(s) }
  end

  def auto_approve_below_days = @setting.get("auto_approve_below_days").to_i
  def manager_can_quick?      = bool("manager_can_quick")
  def ceo_can_force_approve?  = bool("ceo_can_force_approve")
  def require_doc_for_sick?   = bool("require_doc_for_sick")

  def update(params)
    new_chain = Array(params[:chain]).map(&:to_s).select { |s| AVAILABLE_STEPS.include?(s) }
    new_chain = DEFAULTS["chain"] if new_chain.empty?
    @setting.data = (@setting.data || {}).merge(
      "chain"                   => new_chain,
      "auto_approve_below_days" => params[:auto_approve_below_days].to_i,
      "manager_can_quick"       => to_b(params[:manager_can_quick]),
      "ceo_can_force_approve"   => to_b(params[:ceo_can_force_approve]),
      "require_doc_for_sick"    => to_b(params[:require_doc_for_sick])
    )
    @setting.save!
    self
  end

  private

  def bool(key)
    val = @setting.get(key)
    val.nil? ? DEFAULTS[key] : to_b(val)
  end

  def to_b(v) = ActiveModel::Type::Boolean.new.cast(v)
end
