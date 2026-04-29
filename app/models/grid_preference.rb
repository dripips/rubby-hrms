class GridPreference < ApplicationRecord
  belongs_to :user

  KINDS = %w[columns sort filter headerFilter page group density expanded].freeze

  validates :key, :kind, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :key, uniqueness: { scope: %i[user_id kind] }

  scope :for_grid, ->(user, key) { where(user: user, key: key) }

  # Сохраняет один срез (например, "columns") настройки сетки.
  def self.put(user:, key:, kind:, data:)
    record = find_or_initialize_by(user: user, key: key, kind: kind)
    record.data = data || {}
    record.save!
    record
  end

  # Возвращает hash { kind => data } для всех видов настроек по ключу.
  def self.fetch_all(user:, key:)
    for_grid(user, key).pluck(:kind, :data).to_h
  end
end
