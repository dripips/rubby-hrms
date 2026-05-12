# Self-service портал сотрудника: правит ограниченный набор личных полей
# своей employee-карточки. Ничего про salary/grade/department/manager —
# это только HR. Если у user'а нет связанной Employee — отдаём 404-стиль
# редирект на dashboard.
class ProfileController < ApplicationController
  before_action :authenticate_user!
  before_action :load_employee
  helper_method :telegram_bot_username, :telegram_webhook_active?

  EDITABLE_ATTRIBUTES = %i[
    phone personal_email address marital_status
    hobbies dietary_restrictions shirt_size preferred_language
    emergency_contact_name emergency_contact_phone emergency_contact_relation
    has_disability special_needs gender_ref_id
  ].freeze

  def show
    @genders = Gender.where(company: @employee.company).order(:sort_order, :name)
  end

  def edit
    @genders = Gender.where(company: @employee.company).order(:sort_order, :name)
  end

  def update
    apply_custom_fields(@employee, params[:custom_fields])
    if @employee.update(profile_params)
      redirect_to profile_path, notice: t("profile.updated", default: "Данные обновлены")
    else
      @genders = Gender.where(company: @employee.company).order(:sort_order, :name)
      render :edit, status: :unprocessable_entity
    end
  end

  # ── Безопасность: смена пароля + email ──────────────────────────────────
  def security; end

  def update_security
    raw = params.require(:user).permit(:current_password, :email, :password, :password_confirmation, :locale)
    user = current_user

    # Если меняем пароль или email — current_password обязателен
    if raw[:password].present? || raw[:email] != user.email
      unless user.valid_password?(raw[:current_password].to_s)
        flash.now[:alert] = t("profile.security.wrong_password", default: "Текущий пароль неверный")
        render :security, status: :unprocessable_entity
        return
      end
    end

    updates = { email: raw[:email], locale: raw[:locale] }.compact
    updates[:password]              = raw[:password]              if raw[:password].present?
    updates[:password_confirmation] = raw[:password_confirmation] if raw[:password].present?

    if user.update(updates)
      bypass_sign_in(user) if raw[:password].present?  # держим сессию живой
      redirect_to security_profile_path, notice: t("profile.security.updated", default: "Безопасность обновлена")
    else
      render :security, status: :unprocessable_entity
    end
  end

  # ── Уведомления: per-user prefs (in_app/email per kind) ─────────────────
  def notifications
    @kinds = User::NOTIFICATION_KINDS
    @prefs = (current_user.notification_preferences || {})
  end

  def update_notifications
    raw = params[:preferences].to_h
    cleaned = {}
    User::NOTIFICATION_KINDS.each do |kind, _defaults|
      pref = raw[kind].to_h
      cleaned[kind] = User::NOTIFICATION_CHANNELS.each_with_object({}) do |ch, h|
        h[ch.to_s] = pref[ch.to_s] == "1"
      end
    end
    current_user.update!(notification_preferences: cleaned)
    redirect_to notifications_profile_path, notice: t("profile.notifications.updated", default: "Настройки уведомлений сохранены")
  end

  # ── Integrations: Slack webhook + Telegram chat_id ─────────────────────
  def integrations; end

  # One-click Telegram binding: генерит токен, редиректит на t.me/<bot>?start=<token>.
  # Webhook сам сохранит chat_id когда юзер нажмёт Start.
  def start_telegram_link
    bot = telegram_bot_username
    if bot.blank?
      redirect_to integrations_profile_path,
                  alert: t("profile.integrations.tg_bot_missing", default: "Telegram-бот компании не настроен — попроси HR/IT.")
      return
    end

    token = SecureRandom.urlsafe_base64(16)
    current_user.update!(tg_link_token: token, tg_link_token_at: Time.current)

    redirect_to "https://t.me/#{bot}?start=#{token}", allow_other_host: true
  end

  def update_integrations
    raw = params.require(:user).permit(:slack_webhook_url, :telegram_chat_id)
    if current_user.update(raw)
      redirect_to integrations_profile_path,
                  notice: t("profile.integrations.updated", default: "Интеграции сохранены")
    else
      render :integrations, status: :unprocessable_entity
    end
  end

  # Тест: послать тестовое сообщение в Slack для текущего юзера.
  def test_slack
    webhook = current_user.slack_webhook_url.to_s
    if webhook.blank?
      redirect_to integrations_profile_path,
                  alert: t("profile.integrations.no_slack", default: "Сначала впиши Slack webhook URL")
      return
    end

    require "net/http"
    response = Net::HTTP.post(
      URI(webhook),
      { text: "✓ HRMS test — Slack-интеграция работает!" }.to_json,
      "Content-Type" => "application/json"
    )
    if response.is_a?(Net::HTTPSuccess)
      redirect_to integrations_profile_path,
                  notice: t("profile.integrations.slack_test_ok", default: "Тестовое сообщение ушло в Slack")
    else
      redirect_to integrations_profile_path,
                  alert: t("profile.integrations.slack_test_fail", default: "Не получилось — Slack вернул %{code}", code: response.code)
    end
  rescue StandardError => e
    redirect_to integrations_profile_path,
                alert: "Slack error: #{e.message.first(120)}"
  end

  # Тест: послать тестовое сообщение в Telegram.
  def test_telegram
    chat_id   = current_user.telegram_chat_id.to_s
    bot_token = telegram_bot_token

    if chat_id.blank?
      redirect_to integrations_profile_path,
                  alert: t("profile.integrations.no_telegram", default: "Сначала впиши Telegram chat_id")
      return
    end
    if bot_token.blank?
      redirect_to integrations_profile_path,
                  alert: t("profile.integrations.no_bot_token", default: "Админ не настроил бота. Обратись в HR/IT")
      return
    end

    require "net/http"
    response = Net::HTTP.post(
      URI("https://api.telegram.org/bot#{bot_token}/sendMessage"),
      { chat_id: chat_id, text: "✓ HRMS test — Telegram-интеграция работает!" }.to_json,
      "Content-Type" => "application/json"
    )
    if response.is_a?(Net::HTTPSuccess)
      redirect_to integrations_profile_path,
                  notice: t("profile.integrations.telegram_test_ok", default: "Тестовое сообщение ушло в Telegram")
    else
      redirect_to integrations_profile_path,
                  alert: t("profile.integrations.telegram_test_fail", default: "Не получилось — Telegram вернул %{code}", code: response.code)
    end
  rescue StandardError => e
    redirect_to integrations_profile_path,
                alert: "Telegram error: #{e.message.first(120)}"
  end

  # ── GDPR / 152-ФЗ: Privacy ──────────────────────────────────────────────
  def privacy; end

  # Export всех данных юзера в JSON (DSAR — Data Subject Access Request).
  def export_data
    payload = GdprExporter.call(current_user)
    send_data payload.to_json,
              filename: "hrms-data-#{current_user.id}-#{Date.current}.json",
              type:     "application/json",
              disposition: "attachment"
  end

  # Soft-delete аккаунта: discarded_at на User + Employee. Sensitive fields
  # обнуляются (email → "deleted-N@hrms.local", custom_fields → {}). Это GDPR
  # Right to Erasure compliance — данные не уничтожаются полностью (audit
  # требует следы), но PII убирается.
  def delete_account
    unless params[:confirm] == "DELETE"
      redirect_to privacy_profile_path,
                  alert: t("profile.privacy.delete_confirm_required",
                           default: "Введи DELETE заглавными для подтверждения.")
      return
    end

    GdprDeleter.call(current_user)
    sign_out current_user
    redirect_to root_path, notice: t("profile.privacy.deleted", default: "Аккаунт удалён. Прощай.")
  end

  private

  def telegram_bot_token
    ENV["TELEGRAM_BOT_TOKEN"].presence ||
      communication_setting_data["telegram_bot_token"]
  end

  # Reset Current.company memoization при PATCH /profile если subdomain меняется.
  # Здесь явно не используется, но helper доступен.

  def telegram_bot_username
    communication_setting_data["telegram_bot_username"].to_s.presence
  end

  def telegram_webhook_active?
    communication_setting_data["telegram_webhook_url"].to_s.present? &&
      communication_setting_data["telegram_webhook_secret"].to_s.present?
  end

  def communication_setting_data
    @communication_setting_data ||= begin
      (current_company && AppSetting.find_by(company: current_company, category: "communication")&.data) || {}
    end
  end

  def load_employee
    @employee = current_user.employee
    return if @employee

    redirect_to dashboard_path,
                alert: t("profile.no_employee", default: "К аккаунту не привязана карточка сотрудника. Обратись в HR.")
  end

  def profile_params
    params.require(:employee).permit(*EDITABLE_ATTRIBUTES)
  end

  # Слив custom-полей в employee.custom_fields (тот же паттерн что в EmployeesController).
  def apply_custom_fields(employee, raw)
    return unless raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)
    cleaned = raw.to_unsafe_h.transform_values { |v| v.is_a?(String) ? v.strip : v }
    cleaned.reject! { |_, v| v.nil? || (v.is_a?(String) && v.empty?) }
    employee.custom_fields = (employee.custom_fields.to_h || {}).merge(cleaned)
  end
end
