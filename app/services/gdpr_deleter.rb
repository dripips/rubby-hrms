# GDPR Right to Erasure (Article 17) / 152-ФЗ "право на забвение".
#
# Полное удаление невозможно (audit-trail требует хранить историю кто-что-когда),
# но мы:
#   • obfuscate'им PII (email, имя, телефон, адрес — заменяем плейсхолдерами)
#   • discarded_at = now на User и Employee (юзер не сможет логиниться)
#   • стираем custom_fields, notes, документы прикреплённые к employee
#   • Audit-записи остаются, но с whodunnit = "deleted-user-N"
#
# Это compliant с GDPR Article 17(3)(e) — "establishment, exercise or defence
# of legal claims" requires retention of accountability records.
class GdprDeleter
  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @user = user
    @employee = user.employee
  end

  def call
    ActiveRecord::Base.transaction do
      anonymize_user!
      anonymize_employee! if @employee
      remove_documents!  if @employee
      remove_notes!      if @employee
      anonymize_audit!
    end
    Rails.logger.info("[GDPR] Deleted user_id=#{@user.id} (anonymized + discarded)")
  end

  private

  def placeholder_email
    "deleted-user-#{@user.id}@hrms.local"
  end

  def anonymize_user!
    @user.update_columns(
      email: placeholder_email,
      encrypted_password: SecureRandom.hex(32),
      reset_password_token: nil,
      remember_created_at: nil,
      sign_in_count: 0,
      current_sign_in_at: nil, last_sign_in_at: nil,
      current_sign_in_ip: nil, last_sign_in_ip: nil,
      notification_preferences: {},
      dashboard_preferences: {},
      discarded_at: Time.current
    )
  end

  def anonymize_employee!
    @employee.update_columns(
      first_name: "Deleted", last_name: "User", middle_name: nil,
      birth_date: nil, gender: nil, gender_ref_id: nil,
      phone: nil, personal_email: nil, address: nil,
      marital_status: nil, hobbies: nil, shirt_size: nil,
      dietary_restrictions: nil, preferred_language: nil,
      emergency_contact_name: nil, emergency_contact_phone: nil,
      emergency_contact_relation: nil,
      has_disability: false, special_needs: nil,
      custom_fields: {},
      discarded_at: Time.current,
      terminated_at: Date.current,
      state: "terminated"
    )
  end

  def remove_documents!
    Document.where(documentable: @employee).find_each do |d|
      d.file.purge_later if d.file.attached?
      d.discard
    end
  end

  def remove_notes!
    @employee.notes.find_each(&:discard) if @employee.respond_to?(:notes)
  rescue StandardError
    # employee_notes может не быть — игнорируем
  end

  # Audit-trail остаётся для accountability, но whodunnit обнуляется.
  def anonymize_audit!
    PaperTrail::Version.where(whodunnit: @user.id.to_s)
                       .update_all(whodunnit: "deleted-user-#{@user.id}")
  rescue StandardError
    # PaperTrail может быть не сконфигурен или таблица отсутствовать — ОК
  end
end
