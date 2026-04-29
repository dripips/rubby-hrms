class Employee < ApplicationRecord
  include Discard::Model
  include Auditable

  belongs_to :company
  belongs_to :user,       optional: true
  belongs_to :department, optional: true
  belongs_to :position,   optional: true
  belongs_to :grade,      optional: true
  belongs_to :manager,    class_name: "Employee", optional: true
  belongs_to :gender_record, class_name: "Gender", foreign_key: :gender_ref_id, optional: true, inverse_of: :employees

  has_many :reports,         class_name: "Employee", foreign_key: :manager_id, dependent: :nullify, inverse_of: :manager
  has_many :contracts,       dependent: :destroy
  has_many :leave_balances,  dependent: :destroy
  has_many :leave_requests,  dependent: :destroy
  has_many :time_entries,    dependent: :destroy
  has_many :kpi_assignments, dependent: :destroy
  has_many :documents,       as: :documentable, dependent: :destroy
  has_many :children,        class_name: "EmployeeChild", dependent: :destroy
  has_many :notes,           class_name: "EmployeeNote",  dependent: :destroy
  has_many :onboarding_processes,  dependent: :destroy
  has_many :offboarding_processes, dependent: :destroy

  has_one_attached :photo

  MARITAL_STATUSES = %w[single married divorced widowed partnership].freeze
  validates :marital_status, inclusion: { in: MARITAL_STATUSES, allow_blank: true }

  enum :gender,          { unspecified: 0, male: 1, female: 2 }, prefix: true
  enum :employment_type, { full_time: 0, part_time: 1, contract: 2, intern: 3 }, prefix: true
  enum :state,           { probation: 0, active: 1, on_leave: 2, terminated: 3 }, prefix: :state

  validates :personnel_number, presence: true, uniqueness: { scope: :company_id }
  validates :first_name, :last_name, :hired_at, presence: true

  scope :working,     -> { kept.where.not(state: :terminated) }
  scope :active_only, -> { kept.where(state: :active) }

  def full_name
    [last_name, first_name, middle_name].compact_blank.join(" ")
  end

  def short_name
    [last_name, first_name&.first&.upcase].compact_blank.join(" ").then { |s| s.present? ? "#{s}." : "" }
  end

  def initials
    [last_name, first_name].compact.map { |n| n.first&.upcase }.join
  end

  # Gender resolution: prefers configured Gender record, falls back to legacy
  # enum (male/female/unspecified) so existing data keeps working.
  def gender_label
    gender_record&.name || I18n.t("employees.genders.#{gender}", default: gender.to_s.humanize)
  end

  def gender_avatar_seed
    gender_record&.avatar_seed || gender.to_s
  end

  def has_children?
    children.kept.any?
  end

  def upcoming_child_birthdays(within_days: 30)
    children.kept.select do |c|
      next false unless c.birth_date
      bd = c.upcoming_birthday
      bd && (bd - Date.current).to_i <= within_days
    end
  end

  # Source for avatar UI: ActiveStorage if attached, otherwise an external
  # generator that respects gender (DiceBear "personas" set).
  def avatar_url(host: nil)
    return Rails.application.routes.url_helpers.rails_blob_url(photo, host: host || "") if photo.attached?
    seed = "#{full_name}-#{personnel_number}"
    "https://api.dicebear.com/7.x/personas/svg?seed=#{CGI.escape(seed)}&backgroundColor=transparent"
  end
end
