module LeaveRequestsHelper
  def leave_state_tone(state)
    case state.to_s
    when "draft"                          then "neutral"
    when "submitted", "manager_approved"  then "warning"
    when "hr_approved", "active"          then "success"
    when "completed"                      then "info"
    when "rejected"                       then "danger"
    when "cancelled"                      then "neutral"
    else                                       "neutral"
    end
  end
end
