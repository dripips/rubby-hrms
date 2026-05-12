class Settings::CommunicationsController < SettingsController
  before_action :load_setting

  def show
  end

  # POST /settings/communications/test_telegram_bot
  # Дёргает Telegram getMe → если ответ ОК, сохраняем bot_username и id.
  # Это даёт пользователям ссылку https://t.me/<username> на странице
  # /profile/integrations — без необходимости спрашивать у HR/IT.
  def test_bot
    token = @setting.data["telegram_bot_token"].to_s.strip
    if token.blank?
      redirect_to settings_communications_path,
                  alert: t("settings.communications.bot_no_token", default: "Сначала впиши Bot Token")
      return
    end

    require "net/http"
    require "json"
    response = Net::HTTP.get_response(URI("https://api.telegram.org/bot#{token}/getMe"))
    body = JSON.parse(response.body) rescue {}

    if response.is_a?(Net::HTTPSuccess) && body["ok"]
      result = body["result"] || {}
      @setting.update!(data: @setting.data.merge(
        "telegram_bot_username" => result["username"],
        "telegram_bot_name"     => result["first_name"]
      ))
      redirect_to settings_communications_path,
                  notice: t("settings.communications.bot_test_ok",
                            default: "✓ Бот @%{u} (%{n}) подключён",
                            u: result["username"], n: result["first_name"])
    else
      error = body["description"].presence || "HTTP #{response.code}"
      redirect_to settings_communications_path,
                  alert: t("settings.communications.bot_test_fail",
                           default: "Telegram отверг токен: %{e}", e: error)
    end
  rescue StandardError => e
    redirect_to settings_communications_path, alert: "Telegram error: #{e.message.first(120)}"
  end

  # POST /settings/communications/setup_webhook
  # Регистрирует наш /telegram/webhook endpoint у Telegram через setWebhook
  # API. Генерируется случайный secret_token — Telegram отправляет его в
  # заголовке X-Telegram-Bot-Api-Secret-Token (Bot API ≥ 6.7), наш
  # webhook-контроллер проверяет.
  def setup_webhook
    token = @setting.data["telegram_bot_token"].to_s.strip
    if token.blank?
      redirect_to settings_communications_path,
                  alert: t("settings.communications.bot_no_token", default: "Сначала впиши Bot Token")
      return
    end

    base_url = ENV["APP_BASE_URL"].presence ||
               (request.protocol == "http://" && request.local? ? nil : request.base_url)
    if base_url.blank? || base_url.start_with?("http://localhost", "http://127.")
      redirect_to settings_communications_path,
                  alert: t("settings.communications.webhook_local_blocked",
                           default: "Telegram требует HTTPS-публичный URL. На localhost не работает — задай APP_BASE_URL в .env или открой через ngrok-туннель.")
      return
    end

    secret  = SecureRandom.hex(24)
    webhook = "#{base_url}/telegram/webhook"

    require "net/http"
    require "json"
    response = Net::HTTP.post(
      URI("https://api.telegram.org/bot#{token}/setWebhook"),
      { url: webhook, secret_token: secret, allowed_updates: ["message"] }.to_json,
      "Content-Type" => "application/json"
    )
    body = JSON.parse(response.body) rescue {}

    if body["ok"]
      @setting.update!(data: @setting.data.merge(
        "telegram_webhook_url"    => webhook,
        "telegram_webhook_secret" => secret,
        "telegram_webhook_at"     => Time.current.iso8601
      ))
      redirect_to settings_communications_path,
                  notice: t("settings.communications.webhook_ok",
                            default: "✓ Webhook зарегистрирован: %{url}", url: webhook)
    else
      error = body["description"].presence || "HTTP #{response.code}"
      redirect_to settings_communications_path,
                  alert: t("settings.communications.webhook_fail",
                           default: "Telegram отклонил webhook: %{e}", e: error)
    end
  rescue StandardError => e
    redirect_to settings_communications_path, alert: "Telegram setWebhook error: #{e.message.first(120)}"
  end

  # DELETE webhook — снимает регистрацию.
  def delete_webhook
    token = @setting.data["telegram_bot_token"].to_s.strip
    if token.present?
      require "net/http"
      Net::HTTP.post(
        URI("https://api.telegram.org/bot#{token}/deleteWebhook"),
        {}.to_json,
        "Content-Type" => "application/json"
      )
    end
    @setting.update!(data: @setting.data.except("telegram_webhook_url", "telegram_webhook_secret", "telegram_webhook_at"))
    redirect_to settings_communications_path,
                notice: t("settings.communications.webhook_removed", default: "Webhook снят")
  end

  def update
    raw = params.dig(:app_setting, :data) || {}
    raw = raw.respond_to?(:permit!) ? raw.permit!.to_h : raw.to_h
    cleaned = clean_matrix(raw)
    # Глобальный bot_token хранится в той же category=communication, рядом с матрицей
    cleaned["telegram_bot_token"] = raw["telegram_bot_token"].to_s.strip if raw.key?("telegram_bot_token")

    if @setting.update(data: cleaned)
      redirect_to settings_communications_path,
                  notice: t("settings.communications.updated", default: "Правила коммуникации сохранены")
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def company
    @company ||= Company.kept.first
  end

  def load_setting
    @setting = AppSetting.fetch(company: company, category: "communication")
    @setting.data = MessageDispatcher::DEFAULT_MATRIX.deep_merge(@setting.data || {})
  end

  def clean_matrix(raw)
    cleaned = {}
    MessageDispatcher::EVENTS.each do |event|
      cleaned[event] = {}
      MessageDispatcher::RECIPIENT_TYPES.each do |rtype|
        cells = raw.dig(event, rtype) || []
        cells = cells.values if cells.is_a?(Hash)
        # Хранится массив активных каналов: ["email", "telegram"]
        cleaned[event][rtype] = Array(cells)
                                  .map(&:to_s)
                                  .select { |c| MessageDispatcher::CHANNELS.key?(c) }
                                  .uniq
      end
    end
    cleaned
  end
end
