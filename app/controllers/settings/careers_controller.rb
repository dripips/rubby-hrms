class Settings::CareersController < SettingsController
  before_action :load_setting

  def show
    @careers = CareersSettings.new(@setting)
    @public_url = url_for(controller: "careers", action: "index", only_path: false) rescue careers_path
  end

  def update
    raw = params.require(:app_setting).permit!
    incoming = raw.to_h["data"] || {}

    # Файлы — отдельным шагом (ActiveStorage)
    if raw[:logo].present?
      @setting.logo.attach(raw[:logo])
    end
    if raw[:remove_logo] == "1"
      @setting.logo.purge_later
    end
    if raw[:hero_image].present?
      @setting.hero_image.attach(raw[:hero_image])
    end
    if raw[:remove_hero_image] == "1"
      @setting.hero_image.purge_later
    end

    # Базовые скаляры
    cleaned = {
      "enabled"               => truthy(incoming["enabled"]),
      "show_admin_link"       => truthy(incoming["show_admin_link"]),
      "cookie_banner_enabled" => truthy(incoming["cookie_banner_enabled"]),
      "show_salary"           => truthy(incoming["show_salary"]),
      "show_department"       => truthy(incoming["show_department"]),
      "show_employment_type"  => truthy(incoming["show_employment_type"]),
      "contact_email"         => incoming["contact_email"].to_s.strip,
      "layout"                => %w[list grid_2 grid_3].include?(incoming["layout"]) ? incoming["layout"] : "list",
      "per_page"              => incoming["per_page"].to_i.clamp(3, 50),
      "color_primary"         => normalize_hex(incoming["color_primary"]) || "#0A84FF",
      # Сохраняем hero-цвет ТОЛЬКО если чекбокс "use_custom_hero_bg" включён.
      # Иначе nil — hero использует темо-зависимый radial-gradient из --ds-bg-elevated.
      "color_hero_bg"         => (truthy(incoming["use_custom_hero_bg"]) ? normalize_hex(incoming["color_hero_bg"]) : nil),
      "ga_id"                 => clean_id(incoming["ga_id"]),
      "yandex_metrika_id"     => clean_id(incoming["yandex_metrika_id"]),
      "fb_pixel_id"           => clean_id(incoming["fb_pixel_id"]),
      "vk_pixel_id"           => clean_id(incoming["vk_pixel_id"]),
      "api_key"               => @setting.data["api_key"],  # сохраняем существующий
      "api_require_key_apply" => truthy(incoming["api_require_key_apply"]),
      "cors_origins"          => parse_lines(incoming["cors_origins"]),
      "allowed_ips"           => parse_lines(incoming["allowed_ips"])
    }

    # Регенерация ключа по флагу
    if truthy(incoming["regenerate_api_key"])
      cleaned["api_key"] = SecureRandom.urlsafe_base64(32)
    elsif cleaned["api_key"].blank?
      cleaned["api_key"] = SecureRandom.urlsafe_base64(32)
    end

    # Тексты теперь в i18n (Settings → Переводы), не в data["texts"]
    # Cookie categories
    cleaned["cookie_categories"]  = clean_cookie_categories(incoming["cookie_categories"])
    # Pages (только body-Hash{locale})
    cleaned["pages"]              = clean_pages(incoming["pages"])
    # Consents
    cleaned["consents"]           = clean_consents(incoming["consents"])

    @setting.assign_attributes(data: cleaned)

    if @setting.save
      redirect_to settings_careers_path, notice: t("settings.careers.updated", default: "Настройки страницы найма сохранены")
    else
      @careers = CareersSettings.new(@setting)
      render :show, status: :unprocessable_entity
    end
  end

  private

  def company
    @company ||= Company.kept.first
  end

  def load_setting
    @setting = AppSetting.fetch(company: company, category: "careers")
    @setting.data = CareersSettings.deep_merge_defaults(@setting.data || {}, CareersSettings::DEFAULTS)
  end

  def truthy(v) = [ "1", "true", true, 1 ].include?(v)

  def clean_id(v)
    return nil if v.blank?
    s = v.to_s.strip
    s.match?(/\A[A-Za-z0-9._-]{4,40}\z/) ? s : nil
  end

  # Разбивает textarea-значение по строкам/запятым/пробелам — массив строк.
  def parse_lines(v)
    return [] if v.blank?
    v.to_s.split(/[\r\n,;]+/).map(&:strip).reject(&:blank?).uniq
  end

  def normalize_hex(v)
    return nil if v.blank?
    s = v.to_s.strip
    s = "##{s}" unless s.start_with?("#")
    s if s =~ /\A#[0-9a-fA-F]{3,8}\z/
  end

  def clean_locale_hash(h)
    return {} unless h.is_a?(Hash)
    CareersSettings.locales.each_with_object({}) do |loc, acc|
      val = h[loc].to_s.strip
      acc[loc] = val if val.present?
    end
  end

  def clean_cookie_categories(raw)
    return [] unless raw.is_a?(Hash) || raw.is_a?(Array)
    list = raw.is_a?(Hash) ? raw.values : raw
    list.map do |cat|
      next unless cat.is_a?(Hash)
      key = cat["key"].to_s.strip
      next if key.blank?
      { "key" => key, "required" => truthy(cat["required"]), "default" => truthy(cat["default"]) }
    end.compact
  end

  def clean_pages(raw)
    return {} unless raw.is_a?(Hash)
    %w[privacy terms cookies].each_with_object({}) do |slug, acc|
      page = raw[slug] || {}
      acc[slug] = {
        "title" => clean_locale_hash(page["title"]),
        "body"  => clean_locale_hash(page["body"])
      }
    end
  end

  def clean_consents(raw)
    return [] unless raw.is_a?(Hash) || raw.is_a?(Array)
    list = raw.is_a?(Hash) ? raw.values : raw
    list.map do |c|
      next unless c.is_a?(Hash)
      key = c["key"].to_s.strip
      next if key.blank?
      link = nil
      if c["link"].is_a?(Hash) && c["link"]["target"].to_s.strip.present?
        kind = %w[page url].include?(c["link"]["kind"]) ? c["link"]["kind"] : "url"
        link = { "kind" => kind, "target" => c["link"]["target"].to_s.strip }
      end
      { "key" => key, "required" => truthy(c["required"]), "link" => link }
    end.compact
  end
end
