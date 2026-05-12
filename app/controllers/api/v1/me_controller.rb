# /api/v1/me — текущий пользователь + связанный сотрудник.
class Api::V1::MeController < Api::V1::BaseController
  def show
    render json: serialize(current_user)
  end

  def update
    raw = params.permit(:locale, :time_zone, :slack_webhook_url, :telegram_chat_id).to_h
    if current_user.update(raw)
      render json: serialize(current_user)
    else
      render json: { error: "validation_failed", details: current_user.errors.as_json },
             status: :unprocessable_entity
    end
  end

  private

  def serialize(user)
    employee = user.employee
    {
      "id"        => user.id,
      "email"     => user.email,
      "role"      => user.role.to_s,
      "locale"    => user.locale,
      "time_zone" => user.time_zone,
      "two_factor_enabled" => user.two_factor_enabled?,
      "integrations" => {
        "slack_connected"    => user.slack_webhook_url.present?,
        "telegram_connected" => user.telegram_chat_id.present?
      },
      "employee" => employee && {
        "id"               => employee.id,
        "personnel_number" => employee.personnel_number,
        "full_name"        => employee.full_name,
        "first_name"       => employee.first_name,
        "last_name"        => employee.last_name,
        "department"       => employee.department&.name,
        "position"         => employee.position&.name,
        "grade"            => employee.grade&.name,
        "hired_at"         => employee.hired_at,
        "state"            => employee.state,
        "phone"            => employee.phone,
        "personal_email"   => employee.personal_email
      }
    }
  end
end
