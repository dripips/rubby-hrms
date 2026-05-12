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
