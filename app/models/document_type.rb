class DocumentType < ApplicationRecord
  include Discard::Model
  include Auditable

  belongs_to :company
  has_many   :documents, dependent: :destroy

  validates :name, :code, presence: true
  validates :code, uniqueness: { scope: :company_id }

  scope :active, -> { kept.where(active: true).order(:sort_order, :name) }
end
