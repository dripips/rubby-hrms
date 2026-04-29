class Settings::CommunicationsController < SettingsController
  before_action :load_setting

  def show
  end

  def update
    matrix = params.dig(:app_setting, :data) || {}
    matrix = matrix.respond_to?(:permit!) ? matrix.permit!.to_h : matrix.to_h
    cleaned = clean_matrix(matrix)

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
