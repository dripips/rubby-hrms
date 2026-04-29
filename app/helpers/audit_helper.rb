module AuditHelper
  # Pretty-prints a single attribute value from a paper_trail diff.
  # Uses locale-aware formats for Time/Date/Boolean. Falls back to
  # truncated string for everything else. Returns "—" for nil.
  def audit_diff_value(val, length: 60)
    case val
    when nil
      "—"
    when ActiveSupport::TimeWithZone, Time, DateTime
      l(val, format: :audit)
    when Date
      l(val, format: :long)
    when TrueClass
      t("common.yes")
    when FalseClass
      t("common.no")
    when BigDecimal, Float
      number_with_precision(val, precision: 2, strip_insignificant_zeros: true)
    else
      truncate(val.to_s, length: length)
    end
  end
end
