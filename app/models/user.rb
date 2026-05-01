require "bcrypt"

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

  # Devise hook: discarded-юзеры не могут логиниться. Залок через
  # Settings::UsersController#destroy ставит discarded_at.
  def active_for_authentication?
    super && discarded_at.nil?
  end

  def inactive_message
    discarded_at ? :locked : super
  end

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
    "applicant_stage_change" => { in_app: true,  email: false },
    "document_expiring"      => { in_app: true,  email: true  }
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

  # ── 2FA / TOTP (RFC 6238) ──────────────────────────────────────────────
  # otp_secret             — base32, генерится при setup
  # otp_required_for_login — true когда пользователь подтвердил setup TOTP'ом
  # otp_backup_codes       — JSON-array из 10 одноразовых кодов (8 hex chars)
  # otp_enabled_at         — когда юзер прошёл verify (не на setup-старте)
  # otp_last_used_at       — для drift-tracking (анти-replay внутри drift-окна)

  TOTP_ISSUER = "HRMS".freeze
  BACKUP_CODES_COUNT = 10

  def two_factor_enabled?
    otp_required_for_login? && otp_secret.present?
  end

  # Генерит новый секрет (вызывается на старте setup-flow). Не enable'ит до verify.
  def regenerate_otp_secret!
    update!(
      otp_secret: ROTP::Base32.random,
      otp_required_for_login: false,
      otp_enabled_at: nil
    )
  end

  def totp
    return nil if otp_secret.blank?
    ROTP::TOTP.new(otp_secret, issuer: TOTP_ISSUER)
  end

  def otp_provisioning_uri
    totp&.provisioning_uri(email)
  end

  # Проверка кода с drift'ом ±30s. После успеха — пишет otp_last_used_at чтобы
  # не пускать тот же код повторно в пределах того же 30s окна.
  def verify_totp(code)
    return false if code.blank? || totp.nil?
    code = code.to_s.gsub(/\s+/, "")
    timestamp = totp.verify(code, drift_behind: 30, drift_ahead: 30, after: otp_last_used_at)
    return false unless timestamp
    update_column(:otp_last_used_at, Time.zone.at(timestamp))
    true
  end

  # Включает 2FA после успешной верификации первого TOTP-кода. Заодно генерит
  # и возвращает plaintext backup-codes (показываем юзеру 1 раз — потом только хеши).
  def enable_two_factor!
    codes = generate_backup_codes
    update!(
      otp_required_for_login: true,
      otp_enabled_at: Time.current,
      otp_backup_codes: codes.map { |c| ::BCrypt::Password.create(c) }.to_json
    )
    codes
  end

  def disable_two_factor!
    update!(
      otp_secret: nil,
      otp_required_for_login: false,
      otp_enabled_at: nil,
      otp_backup_codes: nil,
      otp_last_used_at: nil
    )
  end

  # Регенерация набора backup-кодов (новый сет, старые становятся невалидны).
  # Возвращает plaintext-коды для показа в UI.
  def regenerate_backup_codes!
    codes = generate_backup_codes
    update!(otp_backup_codes: codes.map { |c| ::BCrypt::Password.create(c) }.to_json)
    codes
  end

  # Verify backup-code: ищет совпадение среди bcrypt-хешей. На совпадении —
  # удаляет использованный хеш (одноразовость).
  def consume_backup_code!(code)
    return false if otp_backup_codes.blank? || code.blank?
    code = code.to_s.strip.downcase
    hashes = JSON.parse(otp_backup_codes) rescue []
    return false if hashes.empty?

    matched_idx = hashes.index { |h| ::BCrypt::Password.new(h) == code rescue false }
    return false unless matched_idx

    hashes.delete_at(matched_idx)
    update_column(:otp_backup_codes, hashes.to_json)
    true
  end

  def remaining_backup_codes_count
    return 0 if otp_backup_codes.blank?
    (JSON.parse(otp_backup_codes) rescue []).size
  end

  private

  def generate_backup_codes
    Array.new(BACKUP_CODES_COUNT) { SecureRandom.hex(4).downcase }
  end
end
