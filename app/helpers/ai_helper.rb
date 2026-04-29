module AiHelper
  def severity_tone(severity)
    case severity.to_s
    when "high"   then "danger"
    when "medium" then "warning"
    else               "info"
    end
  end
end
