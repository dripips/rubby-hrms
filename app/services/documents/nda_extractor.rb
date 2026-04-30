# NDA / Соглашение о неразглашении.
module Documents
  class NdaExtractor < BaseExtractor
    DURATION_RE = /(?:срок|действует|в течение)[:\s]*(\d+)\s*(год|лет|года|месяц|мес)/i.freeze

    def extract
      result = {}

      dates = find_all_dates
      if dates.any?
        result["issued_at"] = dates.first.to_s
        result["valid_until"] = dates[1].to_s if dates.size > 1
      end

      if (m = @text.match(DURATION_RE))
        result["duration_value"] = m[1].to_i
        result["duration_unit"]  = m[2].downcase.start_with?("м") ? "months" : "years"
      end

      penalty = @text.match(/(?:штраф|неустойка)[\s\S]{0,80}?(\d{1,3}(?:[\s ]?\d{3})*)\s*(?:руб|₽|RUB)/i)&.[](1)
      result["penalty_amount"] = penalty.gsub(/[\s ]/, "").to_i if penalty

      result.compact
    end
  end
end
