# Public Careers API v1 — без auth (опционально с X-API-Key для apply),
# CORS + IP whitelist из CareersSettings.
class Api::V1::OpeningsController < ActionController::API
  before_action :set_company
  before_action :enforce_ip_whitelist
  before_action :apply_cors

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "not_found" }, status: :not_found
  end

  def cors_preflight
    head :ok
  end

  def index
    return render(json: { ok: true, alive: true }) if params[:debug] == "ping"

    scope = JobOpening.kept.state_open.where(company: @company)
    scope = scope.where("LOWER(title) LIKE :q OR LOWER(description) LIKE :q OR LOWER(requirements) LIKE :q",
                        q: "%#{params[:q].to_s.strip.downcase}%") if params[:q].present?
    scope = scope.where(department_id: params[:department_id])     if params[:department_id].present?
    scope = scope.where(employment_type: params[:employment_type]) if params[:employment_type].present?

    page  = params[:page].to_i.positive? ? params[:page].to_i : 1
    per   = params[:per].to_i.clamp(1, 50).nonzero? || 10
    total = scope.count
    records = scope.order(published_at: :desc, created_at: :desc)
                   .limit(per).offset((page - 1) * per)
                   .to_a

    payload_data = []
    records.each do |o|
      payload_data << opening_payload(o)
    end

    render json: {
      "meta" => { "page" => page, "per_page" => per, "total" => total, "total_pages" => (total.to_f / per).ceil },
      "data" => payload_data
    }
  end

  def show
    @opening = find_opening!
    render json: { data: opening_payload(@opening, full: true) }
  end

  def apply
    @opening = find_opening!
    careers = CareersSettings.for(@company)

    # Если ключ требуется для apply — проверяем X-API-Key или ?api_key=
    if careers.api_require_key_apply? && !valid_api_key?(careers)
      render json: { ok: false, error: "invalid_api_key" }, status: :unauthorized
      return
    end

    if params[:website].present?
      render(json: { ok: true }) and return
    end
    missing = required_consents_missing(careers)
    if missing.any?
      render json: { ok: false, errors: { consents: "missing_required: #{missing.join(',')}" } }, status: :unprocessable_entity
      return
    end

    applicant = @opening.job_applicants.new(applicant_params.merge(
      company:    @company,
      source:     "api",
      stage:      "applied",
      applied_at: Time.current,
      owner_id:   @opening.owner_id,
      consents:   collected_consents(careers)
    ))

    if applicant.save
      MessageDispatcher.deliver!(event: :application_received, recipient_type: :candidate,
        payload: { applicant: applicant, opening: @opening, company: @company })
      MessageDispatcher.deliver!(event: :new_application, recipient_type: :staff,
        payload: { applicant: applicant, opening: @opening, company: @company })
      render json: { ok: true, id: applicant.id }
    else
      render json: { ok: false, errors: applicant.errors.as_json }, status: :unprocessable_entity
    end
  end

  # Renamed from `config` because that name shadows Rails' internal
  # `controller.config` accessor (used during render pipeline) → infinite loop.
  def widget_config
    careers = CareersSettings.for(@company)
    locale = pick_locale_param

    consents = (careers.setting.data["consents"] || []).map do |c|
      key = c["key"].to_s
      link = c["link"].is_a?(Hash) ? { "kind" => c["link"]["kind"], "target" => c["link"]["target"] } : nil
      {
        "key" => key,
        "required" => c["required"] ? true : false,
        "label" => I18n.with_locale(locale) { I18n.t("careers.public.consent.#{key}.label", default: key.humanize) }.to_s,
        "link" => link
      }
    end

    cookie_cats = (careers.setting.data["cookie_categories"] || []).map do |c|
      key = c["key"].to_s
      {
        "key" => key,
        "required" => c["required"] ? true : false,
        "default"  => c["default"]  ? true : false,
        "label"       => I18n.with_locale(locale) { I18n.t("careers.public.cookie_category.#{key}.label", default: key.humanize) }.to_s,
        "description" => I18n.with_locale(locale) { I18n.t("careers.public.cookie_category.#{key}.description", default: "") }.to_s
      }
    end

    legal = %w[privacy terms cookies].each_with_object({}) do |slug, h|
      body_h = careers.setting.data.dig("pages", slug, "body") || {}
      title_str = I18n.with_locale(locale) { I18n.t("careers.public.page_title_#{slug}", default: slug.humanize) }.to_s
      h[slug] = { "title" => title_str, "body" => (body_h[locale.to_s] || body_h["ru"] || body_h["en"] || "").to_s }
    end

    render json: {
      "site_name"     => careers.site_name(@company&.name).to_s,
      "color_primary" => careers.color_primary.to_s,
      "logo_url"      => logo_url_safe(careers),
      "consents"      => consents,
      "cookie_categories" => cookie_cats,
      "legal_pages"   => legal,
      "texts" => {
        "hero_title"  => I18n.with_locale(locale) { I18n.t("careers.public.hero_title",  default: "") }.to_s,
        "hero_lead"   => I18n.with_locale(locale) { I18n.t("careers.public.hero_lead",   default: "") }.to_s,
        "form_submit" => I18n.with_locale(locale) { I18n.t("careers.public.form_submit", default: "") }.to_s,
        "form_title"  => I18n.with_locale(locale) { I18n.t("careers.public.form_title",  default: "") }.to_s
      }
    }
  end

  private

  def opening_payload(o, full: false)
    base = {
      "id"   => o.id,
      "code" => o.code.to_s,
      "title" => o.title.to_s,
      "department" => o.department&.name.to_s,
      "position"   => o.position&.name.to_s,
      "employment_type" => o.employment_type.to_s,
      "currency"   => o.currency.to_s,
      "salary_from" => o.salary_from&.to_f,
      "salary_to"   => o.salary_to&.to_f,
      "published_at" => o.published_at&.iso8601,
      "excerpt" => o.description.to_s.first(280)
    }
    if full
      base["description"] = o.description.to_s
      base["requirements"] = o.requirements.to_s
      base["nice_to_have"] = o.nice_to_have.to_s
    end
    base
  end

  def find_opening!
    JobOpening.kept.state_open.where(company: @company).find_by(code: params[:code]) ||
      JobOpening.kept.state_open.where(company: @company).find(params[:code])
  end

  def applicant_params
    params.permit(
      :first_name, :last_name, :email, :phone, :location,
      :current_company, :current_position, :years_of_experience,
      :expected_salary, :portfolio_url, :linkedin_url, :github_url, :telegram,
      :summary, :resume, portfolio_files: []
    )
  end

  def collected_consents(careers)
    payload = params[:consents].respond_to?(:to_unsafe_h) ? params[:consents].to_unsafe_h : (params[:consents] || {})
    careers.setting.data["consents"].to_a.each_with_object({}) do |c, acc|
      key = c["key"]
      v = payload[key]
      acc[key] = v.present? && v != "0" && v != false
    end.merge(
      "submitted_at" => Time.current.iso8601,
      "ip"           => request.remote_ip,
      "user_agent"   => request.user_agent.to_s.first(300),
      "via"          => "api"
    )
  end

  def required_consents_missing(careers)
    payload = params[:consents].respond_to?(:to_unsafe_h) ? params[:consents].to_unsafe_h : (params[:consents] || {})
    careers.setting.data["consents"].to_a.select do |c|
      c["required"] && (payload[c["key"]].blank? || payload[c["key"]] == "0" || payload[c["key"]] == false)
    end.map { |c| c["key"] }
  end

  def logo_url_safe(careers)
    return nil unless careers.logo?
    Rails.application.routes.url_helpers.rails_blob_url(careers.logo, host: request.base_url)
  rescue StandardError, SystemStackError
    nil
  end

  def pick_locale_param
    requested = params[:locale].to_s
    if requested.present? && I18n.available_locales.map(&:to_s).include?(requested)
      requested.to_sym
    else
      I18n.default_locale
    end
  end

  def set_company
    @company = Company.kept.first
    head(:service_unavailable) and return unless @company
  end

  def valid_api_key?(careers)
    provided = request.headers["X-API-Key"].to_s.presence || params[:api_key].to_s.presence
    provided.present? && ActiveSupport::SecurityUtils.secure_compare(provided.to_s, careers.api_key.to_s)
  end

  # CORS — origin whitelist из настроек. Если whitelist пуст — '*'.
  # Если задан и origin не разрешён — 403.
  def apply_cors
    careers = CareersSettings.for(@company)
    origin = request.headers["Origin"].to_s

    if careers.cors_origins.any?
      if origin.present? && careers.cors_allows?(origin)
        response.set_header("Access-Control-Allow-Origin", origin)
        response.set_header("Vary", "Origin")
      elsif origin.present?
        render json: { error: "cors_origin_forbidden", origin: origin }, status: :forbidden and return
      end
      # Если origin отсутствует (server-to-server / curl) — пропускаем без CORS-header.
    else
      response.set_header("Access-Control-Allow-Origin", "*")
    end

    response.set_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    response.set_header("Access-Control-Allow-Headers", "Content-Type, Accept, Origin, Authorization, X-API-Key")
    response.set_header("Access-Control-Max-Age",       "3600")
  end

  def enforce_ip_whitelist
    careers = CareersSettings.for(@company)
    return if careers.allowed_ips.empty?
    return if careers.ip_allowed?(request.remote_ip)

    render json: { error: "ip_not_allowed", ip: request.remote_ip }, status: :forbidden
  end
end
