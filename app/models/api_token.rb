# Bearer-token для публичного API (/api/v1/me/* etc).
#
# Поток:
#   1. User создаёт токен в /profile/security → backend генерит raw (32-byte
#      hex), пишет в БД только bcrypt-хеш + 8-char prefix (для UI).
#   2. Raw показывается юзеру ОДИН раз — потом виден только prefix.
#   3. На API-запросе: `Authorization: Bearer <prefix>_<raw>` → ищем по
#      prefix, сравниваем bcrypt(rest) ↔ token_digest.
#   4. last_used_at апдейтится при удачной auth (rate-limited 60s).
#
# Хранение хешем а не plaintext — даже compromised БД не выдаст рабочие
# токены.
require "bcrypt"
require "securerandom"

class ApiToken < ApplicationRecord
  belongs_to :user

  validates :name,         presence: true, length: { maximum: 80 }
  validates :token_digest, presence: true, uniqueness: true
  validates :token_prefix, presence: true, length: { is: 8 }

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

  TOKEN_PREFIX = "hrms".freeze

  class << self
    # Возвращает [token_record, raw_token_string]. raw показывается юзеру 1 раз.
    def issue!(user:, name:, expires_at: nil)
      raw = SecureRandom.hex(32)                       # 64 hex chars
      prefix = SecureRandom.alphanumeric(8).downcase   # уникальный per token
      record = create!(
        user:         user,
        name:         name,
        token_digest: ::BCrypt::Password.create(raw),
        token_prefix: prefix,
        expires_at:   expires_at
      )
      formatted = "#{TOKEN_PREFIX}_#{prefix}_#{raw}"
      [ record, formatted ]
    end

    # Аутентифицирует bearer-токен. Возвращает User или nil.
    # Формат: "hrms_<8-char-prefix>_<64-hex-raw>"
    def authenticate(bearer)
      return nil if bearer.blank?
      parts = bearer.to_s.split("_")
      return nil unless parts.size == 3 && parts[0] == TOKEN_PREFIX
      prefix = parts[1]
      raw    = parts[2]
      return nil if prefix.length != 8 || raw.length != 64

      record = active.find_by(token_prefix: prefix)
      return nil unless record

      stored = ::BCrypt::Password.new(record.token_digest)
      return nil unless stored == raw

      record.touch_last_used!
      record.user.discarded_at.nil? ? record.user : nil
    rescue ::BCrypt::Errors::InvalidHash
      nil
    end
  end

  # Минимизируем DB-запись: апдейтим last_used_at не чаще 60s.
  def touch_last_used!
    return if last_used_at && last_used_at > 60.seconds.ago
    update_column(:last_used_at, Time.current)
  end

  # Для UI: "hrms_abc12345_••••••••"
  def masked
    "#{self.class::TOKEN_PREFIX}_#{token_prefix}_••••••••"
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end
end
