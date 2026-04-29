class Gender < ApplicationRecord
  include Discard::Model
  include Auditable

  belongs_to :company

  has_many :employees, foreign_key: :gender_ref_id, dependent: :nullify, inverse_of: :gender_record
  has_many :employee_children, foreign_key: :gender_ref_id, dependent: :nullify

  validates :code, :name, presence: true
  validates :code, uniqueness: { scope: :company_id }

  scope :active,  -> { kept.where(active: true).order(:sort_order, :name) }
  scope :ordered, -> { kept.order(:sort_order, :name) }

  # Default seed values used to bootstrap a new company.
  DEFAULTS = [
    { code: "male",   name: "Мужской", pronouns: "он/его",   avatar_seed: "male",   sort_order: 1 },
    { code: "female", name: "Женский", pronouns: "она/её",   avatar_seed: "female", sort_order: 2 }
  ].freeze
end
