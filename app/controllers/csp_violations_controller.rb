# Принимает report-only CSP violation отчёты от браузера.
# Браузер POST'ит JSON с описанием нарушения; мы пишем в errors.log
# (тот же лог что HrmsErrorSubscriber из v1.2) для последующего анализа.
#
# Endpoint без auth и без CSRF — это публичный browser-report.
# Rate-limit'ом не парились пока (low-volume); если будет спам — добавим
# rack-attack throttle.
class CspViolationsController < ActionController::API
  def create
    payload = parse_payload

    Rails.error.report(
      "CSP violation",
      severity: :info,
      handled:  true,
      context: {
        kind:          "csp_violation",
        document_uri:  payload.dig("document-uri") || payload.dig("documentURI"),
        violated:      payload.dig("violated-directive") || payload.dig("violatedDirective"),
        blocked:       payload.dig("blocked-uri") || payload.dig("blockedURL"),
        source_file:   payload.dig("source-file") || payload.dig("sourceFile"),
        line:          payload.dig("line-number") || payload.dig("lineNumber"),
        user_agent:    request.user_agent.to_s.first(200)
      }
    )

    head :no_content
  rescue StandardError => e
    Rails.logger.warn("[CspViolations] #{e.class}: #{e.message}")
    head :no_content
  end

  private

  # Браузеры шлют либо классический формат (`csp-report`-wrapped) либо
  # новый reporting-api формат (массив). Поддерживаем оба.
  def parse_payload
    raw = request.raw_post.to_s
    return {} if raw.blank?

    parsed = JSON.parse(raw)
    if parsed.is_a?(Array)
      parsed.first&.dig("body") || {}
    else
      parsed["csp-report"] || parsed
    end
  rescue JSON::ParserError
    {}
  end
end
