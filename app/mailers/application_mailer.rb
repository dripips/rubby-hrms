class ApplicationMailer < ActionMailer::Base
  default from: -> { current_smtp_from }
  layout "mailer"

  # Накатываем SMTP ПОСЛЕ build: in `before_action` self.smtp_settings = {...}
  # настраивает только переменные мейлер-инстанса, но Mail-объект (создаётся
  # внутри `mail()`) копирует delivery_method из дефолта класса один раз —
  # инстансовые установки до него не доходят. Поэтому мы пере-устанавливаем
  # delivery_method уже на готовом message в after_action.
  after_action :apply_runtime_smtp

  private

  def apply_runtime_smtp
    smtp = current_smtp_setting
    return unless smtp&.persisted?

    host = smtp.data["host"].to_s.strip
    return if host.blank?

    port      = (smtp.data["port"] || 587).to_i
    user_tls  = smtp.data["tls"] != false

    # Автоопределение: 465 → implicit SSL/TLS, 587 → STARTTLS,
    # остальное (25) — без шифрования. Юзерский tls-флаг
    # уважаем только для 587: его можно отключить.
    use_ssl     = port == 465
    use_starttls = !use_ssl && user_tls

    settings = {
      address:              host,
      port:                 port,
      domain:               smtp.data["domain"].presence || host.split(".").last(2).join("."),
      user_name:            smtp.data["username"].presence,
      password:             smtp.secret.presence,
      authentication:       smtp.data["authentication"].presence || "plain",
      enable_starttls_auto: use_starttls,
      ssl:                  use_ssl,
      tls:                  use_ssl,
      open_timeout:         15,
      read_timeout:         15
    }.compact

    message.delivery_method :smtp, settings
  end

  def current_smtp_setting
    company = current_company
    return nil if company.nil?

    AppSetting.find_by(company: company, category: "smtp")
  end

  def current_smtp_from
    smtp = current_smtp_setting
    smtp&.data&.dig("from_address").presence || "noreply@hrms.local"
  end
end
