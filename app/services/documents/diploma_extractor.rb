# Диплом ВУЗа / СПО.
module Documents
  class DiplomaExtractor < BaseExtractor
    NUMBER_RE = /\b([А-Я]{2,4}\s?№\s?\d{6,9})\b/.freeze
    DEGREE_RE = /(?:квалификация|степень)[:\s]*([^\n,;]{3,80})/i.freeze
    SPECIALTY_RE = /специальност[ьи][:\s]*([^\n,;]{3,150})/i.freeze
    INSTITUTION_RE = /(?:университет|институт|академия|колледж)/i.freeze

    def extract
      result = {}

      result["number"]    = @text.match(NUMBER_RE)&.[](1)
      result["degree"]    = @text.match(DEGREE_RE)&.[](1)&.strip
      result["specialty"] = @text.match(SPECIALTY_RE)&.[](1)&.strip

      institution_line = @lines.find { |l| l.match?(INSTITUTION_RE) }
      result["institution"] = institution_line&.strip&.first(200) if institution_line

      dates = find_all_dates
      if dates.any?
        result["issued_at"] = dates.first.to_s
        # Год выдачи диплома часто в середине документа — берём последнюю дату как graduation_year
        result["graduation_year"] = dates.last.year
      end

      result.compact
    end
  end
end
