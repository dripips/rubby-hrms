require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"

Bundler.require(*Rails.groups)

module Hrms
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks])

    config.time_zone = "Moscow"
    config.active_record.default_timezone = :utc

    config.i18n.available_locales = %i[ru en de]
    config.i18n.default_locale = :ru
    # ru — primary локаль разработки. Любой missing ключ в en/de фолбэчится на ru,
    # чтобы UI не ломался при отстающих переводах.
    config.i18n.fallbacks = { en: [:ru], de: [:ru] }
    config.i18n.load_path += Dir[Rails.root.join("config", "locales", "**", "*.{rb,yml}")]

    config.generators do |g|
      g.system_tests = nil
      g.test_framework :rspec, fixture: false, view_specs: false, helper_specs: false, routing_specs: false
      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end
  end
end
