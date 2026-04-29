class Language < ApplicationRecord
  include Discard::Model

  enum :direction, { ltr: 0, rtl: 1 }, prefix: true

  validates :code, presence: true, uniqueness: true, format: { with: /\A[a-z]{2}(-[A-Z]{2})?\z/, message: "должен быть в формате 'ru' или 'pt-BR'" }
  validates :native_name, :english_name, presence: true

  scope :enabled,  -> { kept.where(enabled: true).order(:position) }
  scope :ordered,  -> { kept.order(:position) }

  before_save :ensure_single_default

  def self.default
    enabled.find_by(is_default: true) || enabled.first
  end

  def self.available_codes
    Rails.cache.fetch("languages/available_codes", expires_in: 1.minute) do
      enabled.pluck(:code)
    end
  end

  def self.bust_cache!
    Rails.cache.delete("languages/available_codes")
  end

  after_save    -> { self.class.bust_cache!; self.class.sync_runtime_locales!; self.class.reload_routes_safely! }
  after_destroy -> { self.class.bust_cache!; self.class.sync_runtime_locales!; self.class.reload_routes_safely! }

  def self.reload_routes_safely!
    Rails.application.reload_routes!
  rescue StandardError => e
    Rails.logger.warn("[Language] route reload failed: #{e.message}")
  end

  # Синхронизирует I18n.available_locales с БД, чтобы новые языки сразу работали
  # без рестарта сервера. Вызывается после save/destroy.
  def self.sync_runtime_locales!
    db_codes = kept.where(enabled: true).pluck(:code).map(&:to_sym)
    I18n.available_locales = (I18n.available_locales + db_codes).uniq
  rescue StandardError => e
    Rails.logger.warn("[Language] i18n sync failed: #{e.message}")
  end

  private

  def ensure_single_default
    return unless is_default? && (id.nil? || is_default_changed?)

    Language.where.not(id: id).where(is_default: true).update_all(is_default: false)
  end
end
