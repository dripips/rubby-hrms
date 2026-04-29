class User < ApplicationRecord
  include Discard::Model

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :trackable

  enum :role, {
    employee:   0,
    manager:    1,
    hr:         2,
    superadmin: 3
  }, prefix: true

  validates :locale,    inclusion: { in: %w[ru en] }
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }

  scope :active, -> { kept }

  has_one  :employee, dependent: :nullify
  has_many :leave_approvals,  foreign_key: :approver_id,  dependent: :nullify, inverse_of: :approver
  has_many :kpi_evaluations,  foreign_key: :evaluator_id, dependent: :nullify, inverse_of: :evaluator

  has_many :notifications, class_name: "Noticed::Notification", as: :recipient, dependent: :destroy

  # Каталог типов уведомлений с дефолтами по каналам.
  # Структура: { event_key => { in_app: bool, email: bool } }.
  NOTIFICATION_KINDS = {
    "ai_run_completed"       => { in_app: true,  email: false },
    "interview_soon"         => { in_app: true,  email: true  },
    "interview_tomorrow"     => { in_app: true,  email: false },
    "interview_scheduled"    => { in_app: true,  email: true  },
    "interview_cancelled"    => { in_app: true,  email: true  },
    "applicant_stage_change" => { in_app: true,  email: false }
  }.freeze

  def display_name
    employee&.full_name.presence || email.split("@").first.humanize
  end

  def full_role_name
    I18n.t("roles.#{role}", default: role.humanize)
  end

  # Проверка предпочтений: notify_for?("ai_run_completed", :in_app)
  def notify_for?(kind, channel)
    pref = (notification_preferences || {})[kind.to_s]
    return NOTIFICATION_KINDS.dig(kind.to_s, channel.to_sym) || false unless pref.is_a?(Hash)

    if pref.key?(channel.to_s)
      !!pref[channel.to_s]
    else
      NOTIFICATION_KINDS.dig(kind.to_s, channel.to_sym) || false
    end
  end

  # Возвращает текущее значение для UI с учётом дефолта.
  def preference_value(kind, channel)
    notify_for?(kind, channel)
  end
end
