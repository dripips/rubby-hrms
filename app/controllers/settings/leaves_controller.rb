class Settings::LeavesController < SettingsController
  def show
    @config = LeavesSettings.for(company)
  end

  def update
    LeavesSettings.for(company).update(leaves_params)
    redirect_to settings_leaves_path, notice: t("settings.leaves.updated")
  rescue StandardError => e
    redirect_to settings_leaves_path, alert: e.message
  end

  private

  def company
    @company ||= Company.kept.first
  end

  def leaves_params
    raw = params.require(:leaves)
    {
      chain:                   raw[:chain],
      auto_approve_below_days: raw[:auto_approve_below_days],
      manager_can_quick:       raw[:manager_can_quick],
      ceo_can_force_approve:   raw[:ceo_can_force_approve],
      require_doc_for_sick:    raw[:require_doc_for_sick]
    }
  end
end
