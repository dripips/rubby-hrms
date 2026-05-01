# Каталог виджетов дашборда. Каждый виджет — partial под
# app/views/dashboard/widgets/_<key>.html.erb.
#
# Структура user.dashboard_preferences:
#   { "order": ["kpi_tiles", "ai_activity", ...], "hidden": ["onboarding"] }
#
# Если в order не указан какой-то виджет из CATALOG — он добавляется в конец
# (новые виджеты после релиза автоматически появляются у юзера).
class DashboardWidgets
  # ── Catalog ───────────────────────────────────────────────────────────────
  # roles: nil = всем, [..] = только перечисленным
  # full_width: занимает всю строку (не col-12 col-lg-6 и т.п.)
  CATALOG = [
    { key: "kpi_tiles",          label_key: "dashboard.widgets.kpi_tiles",          icon: "trending", roles: nil,                 full_width: true,  default_order: 1 },
    { key: "recent_activity",    label_key: "dashboard.widgets.recent_activity",    icon: "calendar", roles: nil,                 full_width: true,  default_order: 2 },
    { key: "upcoming_events",    label_key: "dashboard.widgets.upcoming_events",    icon: "calendar", roles: nil,                 full_width: false, default_order: 3 },
    { key: "my_kpi",             label_key: "dashboard.widgets.my_kpi",             icon: "trending", roles: nil,                 full_width: false, default_order: 3 },
    { key: "pending_leaves",     label_key: "dashboard.widgets.pending_leaves",     icon: "calendar", roles: %w[hr superadmin manager], full_width: false, default_order: 4 },
    { key: "documents_expiring", label_key: "dashboard.widgets.documents_expiring", icon: "file",     roles: %w[hr superadmin],   full_width: true,  default_order: 5 },
    { key: "burnout_alerts",     label_key: "dashboard.widgets.burnout_alerts",     icon: "trending", roles: %w[hr superadmin],   full_width: false, default_order: 6 },
    { key: "ai_activity",        label_key: "dashboard.widgets.ai_activity",        icon: "trending", roles: %w[hr superadmin],   full_width: false, default_order: 7 },
    { key: "onboarding",         label_key: "dashboard.widgets.onboarding",         icon: "people",   roles: %w[hr superadmin manager], full_width: false, default_order: 8 },
    { key: "offboarding",        label_key: "dashboard.widgets.offboarding",        icon: "people",   roles: %w[hr superadmin manager], full_width: false, default_order: 9 }
  ].freeze

  KEYS = CATALOG.map { |w| w[:key] }.freeze

  # ── Public API ───────────────────────────────────────────────────────────
  # Возвращает список виджетов для конкретного юзера: [{key, label_key, icon,
  # full_width, hidden}], уже отфильтрованный по ролям и упорядоченный
  # согласно prefs пользователя.
  def self.for_user(user)
    prefs   = user.dashboard_preferences.to_h
    order   = Array(prefs["order"]).select { |k| KEYS.include?(k) }
    hidden  = Array(prefs["hidden"]).to_set

    available = CATALOG.select { |w| visible_for?(w, user) }

    # Применяем custom-порядок + добавляем новые ключи в конец
    ordered_keys = order + (available.map { |w| w[:key] } - order)

    ordered_keys.filter_map do |key|
      w = CATALOG.find { |c| c[:key] == key }
      next unless w && visible_for?(w, user)
      w.merge(hidden: hidden.include?(key))
    end
  end

  # Список ВСЕХ доступных юзеру (для UI customize) с пометкой visibility.
  def self.catalog_for_user(user)
    for_user(user)
  end

  # Сохраняет order + hidden от формы. Игнорирует unknown keys.
  def self.save_preferences!(user, order:, hidden:)
    clean_order  = Array(order).map(&:to_s) & KEYS
    clean_hidden = Array(hidden).map(&:to_s) & KEYS
    user.update_columns(dashboard_preferences: {
      "order"  => clean_order,
      "hidden" => clean_hidden
    })
  end

  def self.reset!(user)
    user.update_columns(dashboard_preferences: {})
  end

  # ── helpers ──────────────────────────────────────────────────────────────
  def self.visible_for?(widget, user)
    return true if widget[:roles].nil?
    return false unless user
    widget[:roles].any? { |r| user.role.to_s == r }
  end
end
