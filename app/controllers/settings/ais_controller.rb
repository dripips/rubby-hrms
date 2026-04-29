class Settings::AisController < SettingsController
  before_action :load_setting

  def show
  end

  def update
    @setting.assign_attributes(
      data: filtered_data,
      secret: params.dig(:app_setting, :secret).presence || @setting.secret
    )

    if @setting.save
      redirect_to settings_ai_path, notice: t("settings.ai.updated", default: "AI-настройки сохранены")
    else
      render :show, status: :unprocessable_entity
    end
  end

  def test
    @result = if @setting.secret.blank?
      { ok: false, error: t("settings.ai.no_key", default: "API-ключ не задан") }
    else
      begin
        RecruitmentAi.new(setting: @setting).ping
      rescue StandardError => e
        { ok: false, error: e.message.first(200) }
      end
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("ai-test-result",
                                                  partial: "settings/ais/test_result",
                                                  locals:  { result: @result, setting: @setting })
      end
      format.html do
        if @result[:ok]
          redirect_to settings_ai_path,
                      notice: t("settings.ai.test_ok", default: "Связь установлена · %{tokens} токенов", tokens: @result[:tokens])
        else
          redirect_to settings_ai_path,
                      alert: t("settings.ai.test_fail", default: "Не удалось: %{error}", error: @result[:error])
        end
      end
    end
  end

  private

  def company
    @company ||= Company.kept.first
  end

  def load_setting
    @setting = AppSetting.fetch(company: company, category: "ai")
    @setting.data["model"]                ||= "gpt-5-mini"
    @setting.data["monthly_budget_usd"]   ||= 5
    @setting.data["max_tokens_per_task"]  ||= 1500
    @setting.data["reasoning_effort"]     ||= "minimal"
  end

  def filtered_data
    raw = params.require(:app_setting).permit!.to_h["data"] || {}

    {
      "enabled"              => raw["enabled"] == "1",
      "monthly_budget_usd"   => raw["monthly_budget_usd"].to_f.positive? ? raw["monthly_budget_usd"].to_f : 5,
      "model"                => RecruitmentAi::MODELS.keys.include?(raw["model"]) ? raw["model"] : "gpt-5-mini",
      "provider"             => "openai",
      "max_tokens_per_task"  => raw["max_tokens_per_task"].to_i.positive? ? raw["max_tokens_per_task"].to_i : 1500,
      "reasoning_effort"     => %w[minimal low medium high].include?(raw["reasoning_effort"]) ? raw["reasoning_effort"] : "minimal",
      "proxy_url"            => raw["proxy_url"].to_s.strip,
      "prompts"              => clean_prompts(raw["prompts"]),
      "task_tokens"          => clean_task_tokens(raw["task_tokens"]),
      "task_models"          => clean_task_models(raw["task_models"])
    }
  end

  # task_models: { task_key => model_key }. Пустое = использовать глобальную.
  def clean_task_models(raw)
    return {} unless raw.is_a?(Hash)

    RecruitmentAi::TASK_TOKENS.keys.map(&:to_s).each_with_object({}) do |task, acc|
      val = raw[task].to_s
      acc[task] = val if RecruitmentAi::MODELS.key?(val)
    end
  end

  # Сохраняем только не-пустые промпты (пустое = вернуть к дефолту).
  def clean_prompts(raw)
    return {} unless raw.is_a?(Hash)

    RecruitmentAi::DEFAULT_PROMPTS.keys.each_with_object({}) do |task, acc|
      val = raw[task].to_s.strip
      acc[task] = val if val.present?
    end
  end

  # task_tokens: { task_key => Integer }, валидируем диапазоны.
  def clean_task_tokens(raw)
    return {} unless raw.is_a?(Hash)

    RecruitmentAi::TASK_TOKENS.keys.map(&:to_s).each_with_object({}) do |task, acc|
      val = raw[task].to_i
      acc[task] = val.clamp(200, 16_000) if val.positive?
    end
  end
end
