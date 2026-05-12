# Base для всех authenticated API-эндпоинтов под /api/v1/.
#
# Использование:
#   class Api::V1::MeController < Api::V1::BaseController
#     def show; render json: current_user; end
#   end
#
# Auth flow:
#   Клиент шлёт `Authorization: Bearer hrms_<prefix>_<raw>` header.
#   ApiToken.authenticate валидирует, возвращает User или nil → 401.
#
# Все ответы — JSON. CORS открыт для всех origins (бэк API, не cookie-bound).
class Api::V1::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  before_action :authenticate_api_user!

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "not_found" }, status: :not_found
  end

  rescue_from ActiveRecord::RecordInvalid do |e|
    render json: { error: "validation_failed", details: e.record.errors.as_json }, status: :unprocessable_entity
  end

  rescue_from Pundit::NotAuthorizedError do
    render json: { error: "forbidden" }, status: :forbidden
  end

  attr_reader :current_user

  private

  def authenticate_api_user!
    authenticate_or_request_with_http_token do |token, _options|
      user = ApiToken.authenticate(token)
      @current_user = user
      user.present?
    end
  end

  def request_http_token_authentication(_realm = "Application", _message = nil)
    render json: { error: "unauthorized", hint: "Send Authorization: Bearer hrms_<prefix>_<raw>" },
           status: :unauthorized
  end

  def page;  params[:page].to_i.positive? ? params[:page].to_i : 1; end
  def per;   params[:per].to_i.clamp(1, 100).nonzero? || 25; end
  def paginated(scope, &serializer)
    total = scope.count
    records = scope.limit(per).offset((page - 1) * per).to_a
    {
      "meta" => { "page" => page, "per_page" => per, "total" => total,
                  "total_pages" => (total.to_f / per).ceil },
      "data" => block_given? ? records.map(&serializer) : records
    }
  end
end
