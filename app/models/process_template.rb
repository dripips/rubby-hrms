# Шаблоны процессов онбординга/офбординга. Items хранятся в jsonb как массив
# хешей вида: { title:, description:, kind:, due_offset_days:, position: }.
# При создании OnboardingProcess/OffboardingProcess из шаблона items
# материализуются в OnboardingTask/OffboardingTask.
class ProcessTemplate < ApplicationRecord
  include Discard::Model
  include Auditable

  KINDS = %w[onboarding offboarding].freeze

  TASK_KINDS = {
    "onboarding"  => %w[paperwork equipment access training intro checkin general],
    "offboarding" => %w[kt_session access_revoke equipment_return exit_interview farewell paperwork general]
  }.freeze

  belongs_to :company

  validates :kind, inclusion: { in: KINDS }
  validates :name, presence: true
  validate  :items_must_be_array

  scope :for_company, ->(c) { where(company_id: c.id) }
  scope :active,      -> { kept.where(active: true) }
  scope :ordered,     -> { order(:position, :name) }
  scope :onboarding,  -> { where(kind: "onboarding") }
  scope :offboarding, -> { where(kind: "offboarding") }

  def items_array
    Array(items)
  end

  def task_kinds_allowed
    TASK_KINDS.fetch(kind, %w[general])
  end

  private

  def items_must_be_array
    return if items.is_a?(Array)

    errors.add(:items, "должен быть массивом задач")
  end
end
