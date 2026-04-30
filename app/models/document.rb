# Документ сотрудника (паспорт, договор, NDA, медкнижка и пр.).
# Загружается только HR. Файл хранится через Active Storage.
# Авторазбор: pdf-reader → regex по extractor_kind → extracted_data:jsonb.
# AI используется как fallback (summary длинных договоров, assist если regex
# не справился) — никаких сырых документов в OpenAI без явного запроса.
class Document < ApplicationRecord
  include Discard::Model
  include Auditable
  include AASM

  STATES            = %w[active expired revoked draft].freeze
  CONFIDENTIALITIES = %w[public internal confidential].freeze
  EXTRACTION_METHODS = %w[none gem ai manual].freeze

  belongs_to :documentable, polymorphic: true
  belongs_to :document_type
  belongs_to :created_by, class_name: "User", optional: true

  has_one_attached :file

  validates :document_type_id, presence: true
  validates :state,            inclusion: { in: STATES }
  validates :confidentiality,  inclusion: { in: CONFIDENTIALITIES }
  validates :extraction_method, inclusion: { in: EXTRACTION_METHODS, allow_nil: true }

  scope :active,        -> { kept.where(state: "active") }
  scope :expiring_soon, ->(days = 30) { kept.where(state: "active").where(expires_at: Date.current..(Date.current + days.days)) }
  scope :expired_now,   -> { kept.where("expires_at < ?", Date.current) }
  scope :recent_first,  -> { order(created_at: :desc) }

  aasm column: :state, whiny_persistence: true do
    state :active, initial: true
    state :expired
    state :revoked
    state :draft

    event :expire do
      transitions from: %i[active draft], to: :expired
    end

    event :revoke do
      transitions from: %i[active draft expired], to: :revoked
    end

    event :reactivate do
      transitions from: %i[expired revoked], to: :active, guard: :not_expired_yet?
    end
  end

  def expiring_in_days
    return nil unless expires_at
    (expires_at - Date.current).to_i
  end

  def expired_now?
    expires_at.present? && expires_at < Date.current
  end

  def display_title
    title.presence || "#{document_type&.name} #{number}".strip
  end

  private

  def not_expired_yet?
    expires_at.nil? || expires_at >= Date.current
  end
end
