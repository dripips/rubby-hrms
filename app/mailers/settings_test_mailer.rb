class SettingsTestMailer < ApplicationMailer
  def hello
    @company   = params[:company]
    @from_name = params[:from_name]
    mail(to: params[:to], subject: "[HRMS] Тест SMTP — настройки работают")
  end
end
