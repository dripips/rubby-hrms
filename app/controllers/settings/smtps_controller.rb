class Settings::SmtpsController < SettingsController
  before_action :load_setting

  def show
  end

  def update
    @setting.assign_attributes(
      data: filtered_data,
      secret: params.dig(:app_setting, :secret).presence || @setting.secret
    )

    if @setting.save
      redirect_to settings_smtp_path, notice: t("settings.smtp.updated", default: "SMTP-настройки сохранены")
    else
      render :show, status: :unprocessable_entity
    end
  end

  def test
    @result = begin
      SettingsTestMailer.with(
        company:    company,
        to:         current_user.email,
        from_name:  current_user.display_name
      ).hello.deliver_now

      { ok: true, email: current_user.email }
    rescue StandardError => e
      Rails.logger.error("[smtp test] #{e.class}: #{e.message}")
      { ok: false, error: e.message.first(200) }
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("smtp-test-result",
                                                  partial: "settings/smtps/test_result",
                                                  locals:  { result: @result })
      end
      format.html do
        if @result[:ok]
          redirect_to settings_smtp_path,
                      notice: t("settings.smtp.test_sent", default: "Тестовое письмо отправлено на %{email}", email: @result[:email])
        else
          redirect_to settings_smtp_path,
                      alert: t("settings.smtp.test_failed", default: "Не удалось отправить: %{error}", error: @result[:error])
        end
      end
    end
  end

  private

  def company
    @company ||= current_company
  end

  def load_setting
    @setting = AppSetting.fetch(company: company, category: "smtp")
  end

  def filtered_data
    p = params.require(:app_setting).permit(data: %i[host port username from_address authentication tls])
    data = (p[:data] || {}).to_h
    data["port"]            = data["port"].to_i if data["port"].present?
    data["tls"]             = data["tls"] == "1"
    data["authentication"]  = %w[plain login cram_md5].include?(data["authentication"]) ? data["authentication"] : "plain"
    data
  end
end
