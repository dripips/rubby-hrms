class DictionaryEntry < ApplicationRecord
  include Discard::Model
  include Auditable

  belongs_to :dictionary

  validates :key, :value, presence: true
  validates :key, uniqueness: { scope: :dictionary_id }

  scope :active, -> { kept.where(active: true).order(:sort_order, :value) }
end
