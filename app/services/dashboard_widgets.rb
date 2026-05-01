# Каталог виджетов дашборда. Каждый виджет — partial под
# app/views/dashboard/widgets/_<key>.html.erb.
#
# Структура user.dashboard_preferences:
#   {
#     "order":  ["kpi_tiles", "ai_activity", ...],
#     "hidden": ["onboarding"],
#     "sizes":  { "kpi_tiles" => "l", "my_kpi" => "m", "ai_activity" => "s" }
#   }
#
# Если ключ виджета не указан в order — он добавляется в конец (новые виджеты
# после релиза автоматически появляются у юзера). Если для виджета нет sizes-
# записи — берётся DEFAULT_SIZES, если и там нет — "m".
class DashboardWidgets
  # ── Sizes (iOS-style) ────────────────────────────────────────────────────
  # s = 1 col (compact tile), m = 2 cols (medium card), l = 4 cols (full row).
  # На lg+ грид — 4 колонки, на md — 2, на sm — 1 (всё одной колонкой).
  SIZES = %w[s m l].freeze

  DEFAULT_SIZES = {
    "kpi_tiles"          => "l",
    "recent_activity"    => "l",
    "upcoming_events"    => "m",
    "my_kpi"             => "m",
    "pending_leaves"     => "m",
    "documents_expiring" => "l",
    "burnout_alerts"     => "m",
    "ai_activity"        => "m",
    "onboarding"         => "m",
    "offboarding"        => "m"
  }.freeze

  # ── Catalog ───────────────────────────────────────────────────────────────
  # roles: nil = всем, [..] = только перечисленным
  CATALOG = [
    { key: "kpi_tiles",          label_key: "dashboard.widgets.kpi_tiles",          icon: "trending", roles: nil,                         default_order: 1 },
    { key: "recent_activity",    label_key: "dashboard.widgets.recent_activity",    icon: "calendar", roles: nil,                         default_order: 2 },
    { key: "upcoming_events",    label_key: "dashboard.widgets.upcoming_events",    icon: "calendar", roles: nil,                         default_order: 3 },
    { key: "my_kpi",             label_key: "dashboard.widgets.my_kpi",             icon: "trending", roles: nil,                         default_order: 3 },
    { key: "pending_leaves",     label_key: "dashboard.widgets.pending_leaves",     icon: "calendar", roles: %w[hr superadmin manager],   default_order: 4 },
    { key: "documents_expiring", label_key: "dashboard.widgets.documents_expiring", icon: "file",     roles: %w[hr superadmin],           default_order: 5 },
    { key: "burnout_alerts",     label_key: "dashboard.widgets.burnout_alerts",     icon: "trending", roles: %w[hr superadmin],           default_order: 6 },
    { key: "ai_activity",        label_key: "dashboard.widgets.ai_activity",        icon: "trending", roles: %w[hr superadmin],           default_order: 7 },
    { key: "onboarding",         label_key: "dashboard.widgets.onboarding",         icon: "people",   roles: %w[hr superadmin manager],   default_order: 8 },
    { key: "offboarding",        label_key: "dashboard.widgets.offboarding",        icon: "people",   roles: %w[hr superadmin manager],   default_order: 9 }
  ].freeze

  KEYS = CATALOG.map { |w| w[:key] }.freeze

  # ── Public API ───────────────────────────────────────────────────────────
  # Возвращает виджеты для конкретного юзера: [{key, label_key, icon, hidden,
  # size}], отфильтрованный по ролям и упорядоченный согласно prefs.
  def self.for_user(user)
    prefs   = user.dashboard_preferences.to_h
    order   = Array(prefs["order"]).select { |k| KEYS.include?(k) }
    hidden  = Array(prefs["hidden"]).to_set
    sizes   = prefs["sizes"].is_a?(Hash) ? prefs["sizes"] : {}

    available = CATALOG.select { |w| visible_for?(w, user) }

    # Применяем custom-порядок + добавляем новые ключи в конец.
    ordered_keys = order + (available.map { |w| w[:key] } - order)

    ordered_keys.filter_map do |key|
      w = CATALOG.find { |c| c[:key] == key }
      next unless w && visible_for?(w, user)
      w.merge(
        hidden: hidden.include?(key),
        size:   resolve_size(sizes[key], key)
      )
    end
  end

  def self.catalog_for_user(user)
    for_user(user)
  end

  # Сохраняет order + hidden + sizes от формы. Игнорирует unknown keys.
  def self.save_preferences!(user, order:, hidden:, sizes: nil)
    clean_order  = Array(order).map(&:to_s) & KEYS
    clean_hidden = Array(hidden).map(&:to_s) & KEYS

    raw_sizes  = sizes.respond_to?(:to_unsafe_h) ? sizes.to_unsafe_h : sizes.to_h
    clean_sizes = (raw_sizes || {}).each_with_object({}) do |(k, v), h|
      key = k.to_s
      val = v.to_s
      h[key] = val if KEYS.include?(key) && SIZES.include?(val)
    end

    user.update_columns(dashboard_preferences: {
      "order"  => clean_order,
      "hidden" => clean_hidden,
      "sizes"  => clean_sizes
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

  def self.resolve_size(raw, key)
    return raw if SIZES.include?(raw.to_s)
    DEFAULT_SIZES[key] || "m"
  end
end
