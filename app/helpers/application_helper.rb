module ApplicationHelper
  # Принимает URL от пользователя и возвращает его только если схема http(s).
  # Защита от javascript:/data:/vbscript: схем в href (XSS).
  def safe_external_url(url)
    return nil if url.blank?

    parsed = URI.parse(url.to_s)
    return nil unless %w[http https].include?(parsed.scheme&.downcase)

    parsed.to_s
  rescue URI::InvalidURIError
    nil
  end
end
