# Обёртка над AppSetting(category: "careers") с дефолтами и хелперами.
#
# СТРУКТУРА переехала: все UI-тексты теперь живут в i18n (ru.yml/en.yml + DB-translations
# через Settings → Переводы). Здесь хранятся только per-company настройки:
#   * Скаляры:   enabled, show_admin_link, contact_email, layout, per_page,
#                color_primary, color_hero_bg, show_salary, show_department,
#                show_employment_type, cookie_banner_enabled
#   * Структуры: pages.{slug}.body{locale}, cookie_categories[], consents[]
#
# Лейблы cookie-категорий и consent-айтемов резолвятся через i18n по ключу:
#   careers.public.cookie_category.{key}.label
#   careers.public.cookie_category.{key}.description
#   careers.public.consent.{key}.label
class CareersSettings
  # Список локалей для админки = enabled-языки из БД. Fallback на ru/en
  # если БД пуста (например, до seed'ов или в тесте).
  def self.locales
    @locales_cached_at ||= Time.zone.at(0)
    if Time.current - @locales_cached_at > 30
      codes = (Language.respond_to?(:enabled) ? Language.enabled.pluck(:code) : []) rescue []
      codes = %w[ru en] if codes.empty?
      @locales_cached = codes.uniq
      @locales_cached_at = Time.current
    end
    @locales_cached
  end

  # Backwards compat
  LOCALES = %w[ru en].freeze

  DEFAULTS = {
    "enabled"         => true,
    "show_admin_link" => false,
    "contact_email"   => nil,

    # Layout / Design
    "layout"          => "list",        # list | grid_2 | grid_3
    "per_page"        => 10,
    "color_primary"   => "#0A84FF",
    "color_hero_bg"   => nil,
    "show_salary"     => true,
    "show_department" => true,
    "show_employment_type" => true,

    # Analytics — IDs провайдеров. Пусто = не подключаем.
    "ga_id"           => nil,    # Google Analytics 4 (G-XXXXXXX)
    "yandex_metrika_id" => nil,  # Яндекс.Метрика (89099101)
    "fb_pixel_id"     => nil,    # Facebook Pixel
    "vk_pixel_id"     => nil,    # VK Pixel

    # Public API
    "api_key"               => nil,    # generates on first request from settings
    "api_require_key_apply" => false,  # if true — POST /apply требует X-API-Key header
    "cors_origins"          => [],     # whitelist origins (e.g. https://mycompany.com); пусто = allow *
    "allowed_ips"           => [],     # whitelist IPs/CIDR (например 192.168.1.0/24); пусто = allow all

    "cookie_banner_enabled" => true,

    # Per-locale БОЛЬШИЕ тексты — body legal-страниц.
    # title не настраивается через data — берётся из i18n по ключу
    # `careers.public.page_title_{slug}` → можно перевести через /settings/translations.
    "pages" => {
      "privacy" => { "body" => {
        "ru" => "Текст политики конфиденциальности по 152-ФЗ.\n\nОтредактируйте в Настройки → Страница найма → Юридические страницы.",
        "en" => "Privacy policy text per applicable law (GDPR / CCPA / 152-FZ).\n\nEdit in Settings → Careers → Legal pages."
      } },
      "terms" => { "body" => {
        "ru" => "Текст пользовательского соглашения. Отредактируйте в админке.",
        "en" => "Terms of service text. Edit in admin."
      } },
      "cookies" => { "body" => {
        "ru" => "Информация о том, какие cookies используются на сайте.\n\nКатегории: технические, аналитика, маркетинг.",
        "en" => "Information about cookies used on this site.\n\nCategories: essential, analytics, marketing."
      } }
    },

    # Структура категорий cookie-banner. Лейбл/описание берётся из i18n
    # `careers.public.cookie_category.{key}.{label,description}`.
    "cookie_categories" => [
      { "key" => "essential", "required" => true,  "default" => true  },
      { "key" => "analytics", "required" => false, "default" => false },
      { "key" => "marketing", "required" => false, "default" => false }
    ],

    # Consent-айтемы под формой подачи. Лейбл — из i18n
    # `careers.public.consent.{key}.label`.
    "consents" => [
      { "key" => "personal_data", "required" => true,
        "link" => { "kind" => "page", "target" => "privacy" } },
      { "key" => "terms", "required" => true,
        "link" => { "kind" => "page", "target" => "terms" } },
      { "key" => "marketing", "required" => false, "link" => nil }
    ]
  }.freeze

  attr_reader :setting

  def initialize(setting)
    @setting = setting
  end

  def self.for(company)
    s = AppSetting.fetch(company: company, category: "careers")
    s.data = deep_merge_defaults(s.data || {}, DEFAULTS)
    new(s)
  end

  def self.deep_merge_defaults(data, defaults)
    defaults.each_with_object(data.dup) do |(key, default_val), acc|
      if default_val.is_a?(Hash) && acc[key].is_a?(Hash)
        acc[key] = deep_merge_defaults(acc[key], default_val)
      elsif !acc.key?(key)
        acc[key] = default_val.dup rescue default_val
      end
    end
  end

  # ── Attachments ─────────────────────────────────────────────────────────
  def logo                = setting.logo
  def logo?               = setting.logo.attached?
  def hero_image          = setting.hero_image
  def hero_image?         = setting.hero_image.attached?

  # ── Скаляры ─────────────────────────────────────────────────────────────
  def enabled?            = setting.data["enabled"] != false
  def show_admin_link?    = setting.data["show_admin_link"] == true
  def cookie_banner?      = setting.data["cookie_banner_enabled"] != false
  def contact_email       = setting.data["contact_email"].to_s.strip
  def layout              = setting.data["layout"].presence || "list"
  def per_page            = setting.data["per_page"].to_i.positive? ? setting.data["per_page"].to_i : 10
  def color_primary       = setting.data["color_primary"].presence || "#0A84FF"
  def color_hero_bg       = setting.data["color_hero_bg"].presence
  def show_salary?        = setting.data["show_salary"] != false
  def show_department?    = setting.data["show_department"] != false
  def show_employment_type? = setting.data["show_employment_type"] != false

  # Analytics IDs (sanitize-on-read для безопасности XSS)
  def ga_id              = sanitize_id(setting.data["ga_id"])
  def yandex_metrika_id  = sanitize_id(setting.data["yandex_metrika_id"])
  def fb_pixel_id        = sanitize_id(setting.data["fb_pixel_id"])
  def vk_pixel_id        = sanitize_id(setting.data["vk_pixel_id"])
  def has_analytics?     = ga_id.present? || yandex_metrika_id.present? || fb_pixel_id.present? || vk_pixel_id.present?

  # Public API
  def api_key            = setting.data["api_key"].to_s.presence
  def api_require_key_apply? = setting.data["api_require_key_apply"] == true
  def cors_origins       = Array(setting.data["cors_origins"]).reject(&:blank?)
  def allowed_ips        = Array(setting.data["allowed_ips"]).reject(&:blank?)
  def cors_allows?(origin)
    return true if cors_origins.empty?  # not configured = allow all
    return false if origin.blank?
    cors_origins.any? { |allowed| allowed.strip == origin.strip || allowed.strip == "*" }
  end
  def ip_allowed?(ip)
    return true if allowed_ips.empty?
    return false if ip.blank?
    require "ipaddr"
    allowed_ips.any? do |entry|
      begin
        IPAddr.new(entry.strip).include?(IPAddr.new(ip.to_s))
      rescue StandardError
        false
      end
    end
  end

  private def sanitize_id(v)
    return nil if v.blank?
    s = v.to_s.strip
    s.match?(/\A[A-Za-z0-9._-]{4,40}\z/) ? s : nil
  end

  # ── i18n proxy ──────────────────────────────────────────────────────────
  # Все UI-тексты идут через i18n под `careers.public.*`. Это даёт:
  #   * перевод любого текста на любую enabled-локаль через /settings/translations
  #   * AI-переводы из той же админки
  #   * versioning через стандартный YAML+DB-backend
  def t(key, **opts)
    I18n.t("careers.public.#{key}", **opts)
  end

  # ── Pages (legal: privacy / terms / cookies) ────────────────────────────
  def page(slug)
    body_h = setting.data.dig("pages", slug.to_s, "body") || {}
    {
      title: I18n.t("careers.public.page_title_#{slug}", default: slug.to_s.humanize),
      body:  pick_locale(body_h) || ""
    }
  end

  # ── Site name (override @company.name) ─────────────────────────────────
  # Берётся из i18n careers.public.site_name если задан, иначе fallback.
  def site_name(fallback)
    name_translation = I18n.t("careers.public.site_name", default: "")
    name_translation.presence || fallback.to_s
  end

  # ── Cookie categories / consents — структура из data, label из i18n ────
  def cookie_categories
    (setting.data["cookie_categories"] || []).map do |cat|
      key = cat["key"]
      cat.merge(
        "label_text"       => I18n.t("careers.public.cookie_category.#{key}.label", default: key.to_s.humanize),
        "description_text" => I18n.t("careers.public.cookie_category.#{key}.description", default: "")
      )
    end
  end

  def consents
    (setting.data["consents"] || []).map do |c|
      key = c["key"]
      c.merge(
        "label_text" => I18n.t("careers.public.consent.#{key}.label", default: key.to_s.humanize)
      )
    end
  end

  # ── Универсальный fallback по локалям из любого Hash{locale => str} ───
  def pick_locale(h)
    return nil unless h.is_a?(Hash)
    cur = I18n.locale.to_s
    def_locale = I18n.default_locale.to_s
    h[cur].presence ||
      h[def_locale].presence ||
      h["ru"].presence ||
      h["en"].presence ||
      h.values.find(&:present?)
  end
end
