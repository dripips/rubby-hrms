class Translation < ::I18n::Backend::ActiveRecord::Translation
  self.table_name = "translations"

  validates :locale, :key, presence: true
  validates :key, uniqueness: { scope: :locale }

  scope :for_locale, ->(locale) { where(locale: locale.to_s) }
  scope :search,     ->(q) { q.present? ? where("key ILIKE :q OR value ILIKE :q", q: "%#{q}%") : all }

  after_save    -> { I18n.backend.reload! if I18n.backend.respond_to?(:reload!) }
  after_destroy -> { I18n.backend.reload! if I18n.backend.respond_to?(:reload!) }
end
