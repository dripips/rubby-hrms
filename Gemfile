source "https://rubygems.org"

# ── Core ────────────────────────────────────────────────────────────────────
gem "rails", "~> 8.1.3"
gem "propshaft"
gem "pg", "~> 1.5"
gem "puma", ">= 5.0"
gem "bootsnap", require: false

# Windows does not include zoneinfo files
gem "tzinfo-data", platforms: %i[windows jruby]

# ── Frontend ────────────────────────────────────────────────────────────────
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "dartsass-rails"
gem "bootstrap", "~> 5.3"
gem "image_processing", "~> 1.2"

# ── Database-backed adapters (Rails 8 default) ──────────────────────────────
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"
gem "mission_control-jobs"  # web UI for solid_queue

# ── Auth & authorization ────────────────────────────────────────────────────
gem "devise"
gem "devise-i18n"
gem "pundit"
gem "rotp"                  # TOTP (RFC 6238) для 2FA
gem "rqrcode"               # SVG QR-код для 2FA setup

# ── Domain-specific gems ────────────────────────────────────────────────────
gem "aasm"                  # state machines (leave_requests workflow)
gem "closure_tree"          # department hierarchy via recursive CTE
gem "paper_trail"           # audit log
gem "discard"               # soft delete
gem "ransack"               # search/filter/sort
gem "pg_search"             # full-text search (with Russian morphology)
gem "noticed"               # notifications (in-app + email)
gem "rails-i18n"            # built-in translations for ru/en
gem "i18n-active_record", "~> 1.4", require: "i18n/backend/active_record"
gem "kaminari"              # pagination

# ── Documents (PDF / Excel / OCR) ───────────────────────────────────────────
gem "prawn"
gem "prawn-table"
gem "caxlsx"
gem "caxlsx_rails"
gem "roo"                   # Excel import
gem "pdf-reader"            # extract text from PDFs (pure Ruby, no binaries)
gem "rtesseract"            # OCR for scanned PDFs / images (требует tesseract бинарник)

# ── Deploy ──────────────────────────────────────────────────────────────────
gem "kamal", require: false
gem "thruster", require: false

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "dotenv-rails"
  gem "rspec-rails", "~> 7.1"
  gem "factory_bot_rails"
  gem "faker"
  gem "shoulda-matchers"
end

group :development do
  gem "web-console"
  gem "annotaterb"
  gem "letter_opener"
  gem "letter_opener_web"
  gem "rubocop-rails-omakase", require: false
  gem "ruby-lsp", require: false
end

group :development, :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "bullet"             # N+1 detector — warns в dev / падает в test
end

group :development do
  gem "rack-mini-profiler"  # speed badge в углу страницы, ?pp=help для опций
end

group :test do
  gem "database_cleaner-active_record"
end
