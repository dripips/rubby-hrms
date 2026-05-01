class Dictionary < ApplicationRecord
  include Discard::Model
  include Auditable

  KINDS = %w[lookup field_schema].freeze

  # Типы полей в field_schema-словарях. Контроллер ожидает эти значения в meta["type"].
  FIELD_TYPES = %w[string textarea integer decimal date boolean select].freeze

  belongs_to :company, optional: true
  has_many :entries, -> { order(:sort_order, :value) }, class_name: "DictionaryEntry", dependent: :destroy

  validates :code, :name, presence: true
  validates :code, uniqueness: { scope: :company_id }
  validates :kind, inclusion: { in: KINDS }

  scope :active,        -> { kept }
  scope :lookups,       -> { where(kind: "lookup") }
  scope :field_schemas, -> { where(kind: "field_schema") }

  # field_schema-словарь для конкретного target. Возвращает kept-словарь или nil.
  #   Dictionary.schema_for(company, "DocumentType", doc_type.id)
  def self.schema_for(company, target_model, scope)
    code = "#{target_model}:#{scope}"
    field_schemas.kept.where(company: company, code: code).first
  end

  def lookup?       = kind == "lookup"
  def field_schema? = kind == "field_schema"

  # Для field_schema разбираем code → target_model и scope (id или строка).
  def target_model
    return nil unless field_schema?
    code.to_s.split(":", 2).first
  end

  def target_scope
    return nil unless field_schema?
    code.to_s.split(":", 2).last
  end
end
