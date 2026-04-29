# Multi-language: chain ActiveRecord backend (DB) with the default Simple backend (YAML).
# DB takes precedence — admin-edited values win over YAML defaults.

require "i18n/backend/active_record"

Rails.application.config.after_initialize do
  begin
    if ActiveRecord::Base.connection.data_source_exists?("translations")
      I18n.backend = I18n::Backend::Chain.new(
        I18n::Backend::ActiveRecord.new,
        I18n.backend
      )
    end

    # Расширяем available_locales кодами из БД, чтобы новые языки работали
    # без правки application.rb. Bootstrap-список из application.rb остаётся
    # валидным фолбеком если БД ещё не готова.
    if ActiveRecord::Base.connection.data_source_exists?("languages")
      db_codes = Language.kept.where(enabled: true).pluck(:code).map(&:to_sym)
      I18n.available_locales = (I18n.available_locales + db_codes).uniq
    end
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid
    # DB ещё не создана/мигрирована — оставляем bootstrap-список из application.rb.
  end
end

I18n::Backend::Simple.include(I18n::Backend::Memoize)
I18n::Backend::ActiveRecord.send(:include, I18n::Backend::Memoize) if defined?(I18n::Backend::ActiveRecord)
