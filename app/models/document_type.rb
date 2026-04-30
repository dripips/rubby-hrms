# Справочник типов документов сотрудников. extractor_kind определяет
# какой regex-extractor использовать при автоматическом разборе:
#   passport — серия/номер РФ, дата выдачи, орган
#   snils    — XXX-XXX-XXX YY
#   inn      — 12 digits для физ.лица
#   contract — стороны / период / должность
#   diploma  — ВУЗ / специальность / год
#   nda      — срок / география
#   free     — без специфичного extractor'а (только summary)
class DocumentType < ApplicationRecord
  include Discard::Model
  include Auditable

  EXTRACTOR_KINDS = %w[passport snils inn contract diploma nda medical free].freeze

  belongs_to :company
  has_many   :documents, dependent: :destroy

  validates :name, :code, presence: true
  validates :code, uniqueness: { scope: :company_id }
  validates :extractor_kind, inclusion: { in: EXTRACTOR_KINDS, allow_nil: true }

  scope :active, -> { kept.where(active: true).order(:sort_order, :name) }
end
