# Трудовой договор / доп.соглашение:
#   number         — номер договора
#   issued_at      — дата заключения (первая дата)
#   parties        — стороны (Работодатель / Работник)
#   position       — должность из текста после "должность"
#   salary_amount  — сумма с числом + валюта
module Documents
  class ContractExtractor < BaseExtractor
    NUMBER_RE = /договор[а-я]*\s*№?\s*([A-Z0-9\-\/]+)/i.freeze
    POSITION_RE = /должност[ьи][:\s]*([^\n,;]{3,80})/i.freeze
    SALARY_RE = /(\d{1,3}(?:[\s ]?\d{3})*(?:[.,]\d+)?)\s*(?:руб|рублей|₽|RUB)/i.freeze

    def extract
      result = {}

      result["number"]   = @text[NUMBER_RE, 1]&.strip
      result["position"] = @text[POSITION_RE, 1]&.strip

      dates = find_all_dates
      if dates.any?
        result["issued_at"] = dates.first.to_s
        # Если 2 даты — вторая может быть "Действителен до"
        result["valid_until"] = dates[1].to_s if dates.size > 1
      end

      if (m = @text.match(SALARY_RE))
        result["salary_amount"] = m[1].gsub(/[\s ]/, "").to_f.round(2)
        result["salary_currency"] = "RUB"
      end

      employer = @text.match(/работодател[ьяьем][:\s\-]*([^\n,;]{3,150})/i)&.[](1)
      employee = @text.match(/работник[аеом]?[:\s\-]*([^\n,;]{3,150})/i)&.[](1)
      result["employer"] = employer.strip if employer
      result["employee"] = employee.strip if employee

      result.compact
    end
  end
end
