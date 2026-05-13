class Settings::AisController < SettingsController
  before_action :load_setting

  def show
    @usage = compute_usage
  end

  def update
    @setting.assign_attributes(
      data: filtered_data,
      secret: params.dig(:app_setting, :secret).presence || @setting.secret
    )

    if @setting.save
      redirect_to settings_ai_path, notice: t("settings.ai.updated", default: "AI-настройки сохранены")
    else
      @usage = compute_usage
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
    @company ||= current_company
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

    provider = RecruitmentAi::PROVIDER_PRESETS.key?(raw["provider"]) ? raw["provider"] : "openai"
    # Для OpenAI режем под whitelisted-модели; для остальных принимаем
    # free-form строку (любая модель которую понимает endpoint).
    model = if provider == "openai"
              RecruitmentAi::MODELS.key?(raw["model"]) ? raw["model"] : "gpt-5-mini"
    else
              raw["model"].to_s.strip.presence || ""
    end

    {
      "enabled"              => raw["enabled"] == "1",
      "monthly_budget_usd"   => raw["monthly_budget_usd"].to_f.positive? ? raw["monthly_budget_usd"].to_f : 5,
      "model"                => model,
      "provider"             => provider,
      "api_base_url"         => raw["api_base_url"].to_s.strip,
      "max_tokens_per_task"  => raw["max_tokens_per_task"].to_i.positive? ? raw["max_tokens_per_task"].to_i : 1500,
      "reasoning_effort"     => %w[minimal low medium high].include?(raw["reasoning_effort"]) ? raw["reasoning_effort"] : "minimal",
      "proxy_url"            => raw["proxy_url"].to_s.strip,
      "openrouter_referer"   => raw["openrouter_referer"].to_s.strip,
      "openrouter_app_title" => raw["openrouter_app_title"].to_s.strip,
      "prompts"              => clean_prompts(raw["prompts"]),
      "task_tokens"          => clean_task_tokens(raw["task_tokens"]),
      "task_models"          => clean_task_models(raw["task_models"])
    }
  end

  # Аггрегаты по AiRun для дашборда «фактический расход».
  # Важно: cost_usd на не-OpenAI моделях = 0 (мы не знаем расценки), поэтому
  # для них показываем только токены и количество запусков.
  def compute_usage
    now = Time.current
    month_start      = now.beginning_of_month
    last_month_start = (now - 1.month).beginning_of_month
    last_month_end   = month_start

    base = AiRun.where.not(kind: "ping")

    {
      this_month_usd:    base.where(created_at: month_start..).sum(:cost_usd),
      last_month_usd:    base.where(created_at: last_month_start..last_month_end).sum(:cost_usd),
      all_time_usd:      base.sum(:cost_usd),
      this_month_runs:   base.where(created_at: month_start..).count,
      this_month_tokens: base.where(created_at: month_start..).sum(:total_tokens),
      budget_usd:        @setting.data["monthly_budget_usd"].to_f,

      by_kind: base.where(created_at: month_start..)
                   .group(:kind)
                   .pluck(:kind, Arel.sql("COUNT(*)"), Arel.sql("SUM(cost_usd)"), Arel.sql("SUM(total_tokens)"))
                   .map { |k, c, u, t| { kind: k, count: c, usd: u.to_f, tokens: t.to_i } }
                   .sort_by { |r| -r[:usd] }
                   .first(15),

      by_model: base.where(created_at: month_start..)
                    .group(:model)
                    .pluck(:model, Arel.sql("COUNT(*)"), Arel.sql("SUM(cost_usd)"), Arel.sql("SUM(total_tokens)"))
                    .map { |m, c, u, t| { model: m, count: c, usd: u.to_f, tokens: t.to_i } }
                    .sort_by { |r| -r[:usd] }
                    .first(10),

      recent: base.includes(:user).order(created_at: :desc).limit(20)
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
