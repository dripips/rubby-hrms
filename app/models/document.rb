class Document < ApplicationRecord
  include Discard::Model
  include Auditable

  belongs_to :documentable, polymorphic: true
  belongs_to :document_type
  has_one_attached :file

  validates :document_type_id, presence: true

  scope :active,        -> { kept }
  scope :expiring_soon, ->(days = 30) { kept.where(expires_at: Date.current..(Date.current + days.days)) }
end
