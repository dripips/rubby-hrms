# ИНН: 12 цифр для физ.лица или 10 для юр.лица. Здесь — физ.лицо.
module Documents
  class InnExtractor < BaseExtractor
    INN_PHYSICAL_RE = /\b(\d{12})\b/.freeze
    INN_LABELED_RE  = /ИНН[:\s\-]*(\d{10,12})/i.freeze

    def extract
      result = {}

      number = @text.match(INN_LABELED_RE)&.[](1) ||
               @text.match(INN_PHYSICAL_RE)&.[](1)
      result["number"] = number if number

      dates = find_all_dates
      result["issued_at"] = dates.first.to_s if dates.any?

      result.compact
    end
  end
end
