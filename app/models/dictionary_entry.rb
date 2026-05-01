class DictionaryEntry < ApplicationRecord
  include Discard::Model
  include Auditable

  belongs_to :dictionary

  validates :key, :value, presence: true
  validates :key, uniqueness: { scope: :dictionary_id }, format: { with: /\A[a-z][a-z0-9_]*\z/, message: :invalid_key }

  scope :active, -> { kept.where(active: true).order(:sort_order, :value) }

  # ── helpers для field_schema ──────────────────────────────────────────────
  # Структура meta для field_schema-entries:
  #   { "type" => "string|textarea|integer|decimal|date|boolean|select",
  #     "required" => true|false,
  #     "hint"     => "подсказка под полем",
  #     "options"  => ["a", "b", "c"]   # только для type=select
  #   }

  def field_type    = meta.to_h["type"].presence || "string"
  def field_required = meta.to_h["required"] == true || meta.to_h["required"] == "true" || meta.to_h["required"] == "1"
  def field_hint    = meta.to_h["hint"].to_s
  def field_options
    raw = meta.to_h["options"]
    case raw
    when Array  then raw.map(&:to_s).reject(&:empty?)
    when String then raw.split(/[,\n]/).map(&:strip).reject(&:empty?)
    else []
    end
  end
end
