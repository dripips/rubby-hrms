# Универсальный key-value сохранятор настроек уровня компании.
# Каждая категория (smtp/ai/...) — одна строка с jsonb data + опц. secret.
class AppSetting < ApplicationRecord
  include Auditable

  belongs_to :company

  # Attachments (используются категорией careers — лого, hero-фон)
  has_one_attached :logo
  has_one_attached :hero_image

  CATEGORIES = %w[smtp ai communication telegram whatsapp careers leaves].freeze
  validates :category, inclusion: { in: CATEGORIES }
  validates :company_id, uniqueness: { scope: :category }

  # Лениво создаём запись с дефолтами при первом обращении.
  def self.fetch(company:, category:)
    find_or_initialize_by(company: company, category: category).tap do |s|
      s.data ||= {}
    end
  end

  def get(key) = data[key.to_s]

  def set(key, value)
    self.data = (data || {}).merge(key.to_s => value)
  end
end
