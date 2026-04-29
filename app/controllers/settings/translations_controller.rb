class Settings::TranslationsController < SettingsController
  def index
    @locales = Language.enabled
    @current_locale = params[:locale].presence_in(@locales.map(&:code)) || Language.default&.code || I18n.default_locale.to_s
    @query = params[:q].to_s.strip

    yaml_keys = collect_yaml_keys(@current_locale)
    db_rows   = Translation.for_locale(@current_locale).search(@query).pluck(:key, :value).to_h

    @rows = yaml_keys.map do |key|
      yaml_value = lookup_yaml(@current_locale, key)
      db_value   = db_rows[key]
      {
        key: key,
        yaml: yaml_value.is_a?(String) ? yaml_value : nil,
        db: db_value,
        effective: db_value || (yaml_value.is_a?(String) ? yaml_value : nil)
      }
    end

    if @query.present?
      q = @query.downcase
      @rows = @rows.select { |r| r[:key].downcase.include?(q) || r[:yaml].to_s.downcase.include?(q) || r[:db].to_s.downcase.include?(q) }
    end

    @rows = @rows.first(500)  # safety limit
  end

  def update
    record = Translation.find(params[:id])
    if record.update(value: params[:translation][:value])
      I18n.backend.reload! if I18n.backend.respond_to?(:reload!)
      redirect_back fallback_location: settings_translations_path, notice: t("settings.translations.updated", default: "Перевод сохранён")
    else
      redirect_back fallback_location: settings_translations_path, alert: record.errors.full_messages.to_sentence
    end
  end

  def create
    record = Translation.find_or_initialize_by(locale: params[:translation][:locale], key: params[:translation][:key])
    record.value = params[:translation][:value]
    if record.save
      I18n.backend.reload! if I18n.backend.respond_to?(:reload!)
      redirect_back fallback_location: settings_translations_path, notice: t("settings.translations.saved", default: "Перевод сохранён")
    else
      redirect_back fallback_location: settings_translations_path, alert: record.errors.full_messages.to_sentence
    end
  end

  private

  # Walk YAML translations for the given locale and return all flat keys (a.b.c).
  def collect_yaml_keys(locale)
    flat = {}
    walk = ->(prefix, node) do
      case node
      when Hash
        node.each { |k, v| walk.call([ prefix, k ].compact.join("."), v) }
      else
        flat[prefix] = node
      end
    end
    yaml_root = simple_backend_translations(locale)
    walk.call(nil, yaml_root) if yaml_root.is_a?(Hash)
    flat.keys.sort
  end

  def lookup_yaml(locale, key)
    parts = key.split(".").map(&:to_sym)
    parts.reduce(simple_backend_translations(locale)) { |memo, k| memo.is_a?(Hash) ? memo[k] : nil }
  end

  def simple_backend_translations(locale)
    backends = if I18n.backend.is_a?(I18n::Backend::Chain)
      I18n.backend.backends
    else
      [ I18n.backend ]
    end
    simple = backends.find { |b| b.is_a?(I18n::Backend::Simple) } || I18n.backend
    simple.send(:init_translations) unless simple.send(:initialized?)
    simple.send(:translations)[locale.to_sym] || {}
  end
end
