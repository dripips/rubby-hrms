# СНИЛС: формат XXX-XXX-XXX YY (11 цифр + контрольная пара).
module Documents
  class SnilsExtractor < BaseExtractor
    SNILS_RE = /\b(\d{3}-\d{3}-\d{3}\s\d{2})\b/.freeze

    def extract
      result = {}
      if (m = @text.match(SNILS_RE))
        result["number"] = m[1]
      end

      dates = find_all_dates
      result["issued_at"] = dates.first.to_s if dates.any?

      result.compact
    end
  end
end
