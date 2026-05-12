# Скриншоты для README — автоматический обход ключевых страниц через
# headless Chrome (selenium-webdriver). Запускать когда сервер уже поднят
# на http://localhost:4000 (или указать APP_URL).
#
# Usage:
#   bin/rails screenshots                # все страницы
#   bin/rails screenshots[dashboard]     # одна страница
#   APP_URL=https://hrms.example.com bin/rails screenshots
#
# Логинится как admin@hrms.local / password123, обходит SHOTS, сохраняет
# в docs/screenshots/*.png размера 1440×900.

namespace :screenshots do
  WIDTH        = 1440
  HEIGHT       = 900
  WAIT         = 2.5  # сек после navigate — дать Stimulus / FullCalendar поднять UI
  SCREENS_DIR  = Rails.root.join("docs", "screenshots")
  APP_URL      = ENV["APP_URL"].presence || "http://localhost:4000"
  EMAIL        = ENV["ADMIN_EMAIL"].presence    || "admin@hrms.local"
  PASSWORD     = ENV["ADMIN_PASSWORD"].presence || "password123"
  LOCALES      = (ENV["LOCALES"].presence&.split(",") || %w[ru en de]).map(&:strip)

  # Список страниц для скрина: filename → URL path + optional wait/scroll/etc.
  SHOTS = [
    { file: "01-dashboard",            path: "/dashboard" },
    { file: "02-employees",            path: "/employees" },
    { file: "03-recruitment-kanban",   path: "/recruitment/kanban" },
    { file: "04-recruitment-calendar", path: "/recruitment/calendar", wait: 4 },
    { file: "05-recruitment-analytics", path: "/recruitment/analytics" },
    { file: "06-leave-requests",       path: "/leave_requests" },
    { file: "07-kpi-dashboard",        path: "/kpi/dashboard" },
    { file: "08-documents",            path: "/documents" },
    { file: "09-onboarding",           path: "/onboarding_processes" },
    { file: "10-audit",                path: "/audit" },
    { file: "11-profile",              path: "/profile" },
    { file: "12-profile-integrations", path: "/profile/integrations" },
    { file: "13-settings-languages",   path: "/settings/languages" },
    { file: "14-settings-ai",          path: "/settings/ai" },
    { file: "15-ai-runs",              path: "/ai_runs" }
  ].freeze

  # Какие странички повторить в тёмной теме (только эстетически-показательные —
  # dashboard / kanban / KPI). Файлы получают суффикс -dark.
  DARK_SHOT_FILES = %w[01-dashboard 03-recruitment-kanban 07-kpi-dashboard 04-recruitment-calendar].freeze

  desc "Take all README screenshots (per locale, light + dark)"
  task all: :environment do
    only = ENV["ONLY"].to_s.split(",").map(&:strip)
    shots = only.any? ? SHOTS.select { |s| only.include?(s[:file]) } : SHOTS
    dark_shots = SHOTS.select { |s| DARK_SHOT_FILES.include?(s[:file]) }
    dark_shots = [] if only.any? && (only & DARK_SHOT_FILES).empty?
    drive(shots, dark_shots)
  end

  def drive(shots, dark_shots = [])
    require "selenium-webdriver"
    require "fileutils"

    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless=new")
    options.add_argument("--disable-gpu")
    options.add_argument("--hide-scrollbars")
    options.add_argument("--force-device-scale-factor=1")
    options.add_argument("--window-size=#{WIDTH},#{HEIGHT}")

    driver = Selenium::WebDriver.for(:chrome, options: options)
    driver.manage.window.resize_to(WIDTH, HEIGHT)

    sign_in!(driver)

    LOCALES.each do |locale|
      locale_dir = SCREENS_DIR.join(locale)
      FileUtils.mkdir_p(locale_dir)

      puts "\n═══ locale: #{locale.upcase} ═══"
      set_theme!(driver, "light")

      shots.each { |shot| capture(driver, shot, locale: locale, suffix: "") }

      if dark_shots.any?
        puts "→ switching to dark theme"
        set_theme!(driver, "dark")
        dark_shots.each { |shot| capture(driver, shot, locale: locale, suffix: "-dark") }
      end
    end
  ensure
    driver&.quit
  end

  def capture(driver, shot, locale:, suffix:)
    url  = "#{APP_URL}/#{locale}#{shot[:path]}"
    file = SCREENS_DIR.join(locale, "#{shot[:file]}#{suffix}.png")
    puts "→ #{(shot[:file] + suffix).ljust(34)} #{url}"
    driver.navigate.to(url)
    sleep(shot[:wait] || WAIT)
    driver.save_screenshot(file.to_s)
    puts "  ✓ #{file.basename}"
  rescue StandardError => e
    puts "  ✗ #{e.class}: #{e.message.first(120)}"
  end

  # Set theme via cookie (matches ApplicationController#current_theme).
  def set_theme!(driver, theme)
    driver.manage.add_cookie(name: "theme", value: theme, path: "/")
  end

  def sign_in!(driver)
    puts "→ sign in as #{EMAIL}"
    driver.navigate.to("#{APP_URL}/users/sign_in")
    sleep 1.2
    driver.find_element(id: "user_email").send_keys(EMAIL)
    driver.find_element(id: "user_password").send_keys(PASSWORD)
    driver.find_element(css: "form button[type='submit'], form input[type='submit']").click
    sleep 2.0
    if driver.current_url.include?("/sign_in")
      raise "Sign-in failed: still on #{driver.current_url}"
    end
    puts "  ✓ signed in (#{driver.current_url})"
  end
end

desc "Take README screenshots — alias for screenshots:all"
task screenshots: "screenshots:all"
