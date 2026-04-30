# Медицинская книжка / справка.
module Documents
  class MedicalExtractor < BaseExtractor
    NUMBER_RE = /(?:книжк[аиу]|справк[аиу])\s*№?\s*([A-Z0-9\-\/]{3,30})/i.freeze

    def extract
      result = {}
      result["number"] = @text.match(NUMBER_RE)&.[](1)

      dates = find_all_dates
      if dates.any?
        result["issued_at"]   = dates.first.to_s
        result["valid_until"] = dates[1].to_s if dates.size > 1
      end

      institution = @lines.find { |l| l.match?(/(?:поликлиника|больница|медцентр|центр здоровья)/i) }
      result["institution"] = institution&.strip&.first(200) if institution

      result.compact
    end
  end
end
