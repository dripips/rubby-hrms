# Простейший контроллер чтобы изолировать source рекурсии.
class Api::V1::PingController < ActionController::API
  def index
    render json: { ok: true, ts: Time.current.to_i }
  end
end
