# Резолвит тенанта по subdomain'у и кладёт в Current.company.
#
# Логика:
#   acme.hrms.example.com   → Company.find_by(subdomain: "acme")
#   hrms.example.com        → fallback Company.kept.first (single-tenant mode)
#   www.* / api.*           → тот же fallback
#
# В dev/test:
#   localhost:4000          → fallback (нет subdomain'а)
#   acme.localhost:4000     → Company.find_by(subdomain: "acme")
#
# Если subdomain указан но company не найдена → 404 + JSON для API.
class TenantResolver
  IGNORED_SUBDOMAINS = %w[www api app].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    subdomain = request.subdomains.first.to_s.downcase

    company = resolve(subdomain)
    if subdomain.present? && !IGNORED_SUBDOMAINS.include?(subdomain) && company.nil?
      return tenant_not_found(request)
    end

    Current.company = company || Company.kept.first
    @app.call(env)
  ensure
    Current.reset
  end

  private

  def resolve(subdomain)
    return nil if subdomain.blank? || IGNORED_SUBDOMAINS.include?(subdomain)
    Company.kept.find_by(subdomain: subdomain)
  rescue ActiveRecord::ActiveRecordError, ActiveRecord::ConnectionNotEstablished
    # Во время первого boot'а БД может быть недоступна (миграции) — не падаем.
    nil
  end

  def tenant_not_found(request)
    body = if request.path.start_with?("/api/")
      [ { error: "tenant_not_found", subdomain: request.subdomains.first }.to_json ]
    else
      [ "<h1>404 — tenant not found</h1>".html_safe ]
    end
    content_type = request.path.start_with?("/api/") ? "application/json" : "text/html"
    [ 404, { "Content-Type" => content_type }, body ]
  end
end
