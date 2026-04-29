class ApplicationController < ActionController::Base
  include Pundit::Authorization

  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :set_locale
  before_action :set_paper_trail_whodunnit
  around_action :capture_audit_request_context
  around_action :switch_time_zone, if: :user_signed_in?

  rescue_from Pundit::NotAuthorizedError,    with: :user_not_authorized
  rescue_from ActiveRecord::RecordNotFound,  with: :record_not_found
  rescue_from ActionController::RoutingError, with: :record_not_found

  helper_method :current_theme

  def default_url_options(options = {})
    { locale: I18n.locale == I18n.default_locale ? nil : I18n.locale }.merge(options)
  end

  private

  def set_locale
    I18n.locale = locale_from_params || locale_from_user || I18n.default_locale
  end

  def locale_from_params
    locale = params[:locale]
    return nil unless locale.present? && I18n.available_locales.map(&:to_s).include?(locale)

    cookies.permanent[:locale] = locale
    locale
  end

  def locale_from_user
    return current_user.locale if user_signed_in? && current_user.locale.present?

    cookies[:locale]
  end

  def switch_time_zone(&block)
    Time.use_zone(current_user.time_zone, &block)
  end

  def capture_audit_request_context(&block)
    AuditLogger.with_request(request) do
      # Push the request-level context into PaperTrail.request so that
      # any version created during this controller action gets metadata
      # written to its `metadata` jsonb column automatically.
      PaperTrail.request(controller_info: { metadata: AuditLogger.request_context }, &block)
    end
  end

  def current_theme
    cookies[:theme].presence_in(%w[light dark]) || "auto"
  end

  def user_not_authorized
    flash[:alert] = t("pundit.not_authorized", default: "Доступ запрещён")
    redirect_back fallback_location: root_path
  end

  def record_not_found
    respond_to do |format|
      format.html { render template: "errors/not_found", status: :not_found, layout: "application" }
      format.json { render json: { error: t("errors.not_found.title") }, status: :not_found }
      format.any  { head :not_found }
    end
  end
end
