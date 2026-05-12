class Settings::CommunicationsController < SettingsController
  before_action :load_setting

  def show
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
