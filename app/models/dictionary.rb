class Dictionary < ApplicationRecord
  include Discard::Model
  include Auditable

  belongs_to :company, optional: true
  has_many :entries, class_name: "DictionaryEntry", dependent: :destroy

  validates :code, :name, presence: true
  validates :code, uniqueness: { scope: :company_id }

  scope :active, -> { kept }
end
