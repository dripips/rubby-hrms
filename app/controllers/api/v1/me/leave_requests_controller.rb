class Api::V1::Me::LeaveRequestsController < Api::V1::BaseController
  def index
    emp = current_user.employee
    return render(json: paginated_empty) unless emp

    scope = emp.leave_requests.includes(:leave_type).order(started_on: :desc)
    scope = scope.where(state: params[:state]) if params[:state].present?

    render json: paginated(scope) { |lr| serialize(lr) }
  end

  def create
    emp = current_user.employee
    return render(json: { error: "no_employee_linked" }, status: :unprocessable_entity) unless emp

    leave = emp.leave_requests.new(
      leave_type_id: params[:leave_type_id],
      started_on:    params[:started_on],
      ended_on:      params[:ended_on],
      reason:        params[:reason]
    )
    if leave.save
      render json: serialize(leave), status: :created
    else
      render json: { error: "validation_failed", details: leave.errors.as_json },
             status: :unprocessable_entity
    end
  end

  private

  def serialize(lr)
    {
      "id"         => lr.id,
      "leave_type" => lr.leave_type&.name,
      "started_on" => lr.started_on,
      "ended_on"   => lr.ended_on,
      "days"       => lr.days,
      "state"      => lr.state,
      "reason"     => lr.reason,
      "created_at" => lr.created_at&.iso8601
    }
  end

  def paginated_empty
    { "meta" => { "page" => 1, "per_page" => per, "total" => 0, "total_pages" => 0 }, "data" => [] }
  end
end
