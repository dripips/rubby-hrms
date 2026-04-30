# Извлекает данные паспорта РФ:
#   number       — серия + номер (ХХХХ ХХХХХХ)
#   issued_at    — дата выдачи (Date)
#   issuer       — кем выдан (одной строкой)
#   issuer_code  — код подразделения (ХХХ-ХХХ)
#   birth_date   — дата рождения
module Documents
  class PassportExtractor < BaseExtractor
    # Серия (4 цифры, иногда с пробелом 12 34) + номер (6 цифр).
    # Между ними может быть "номер" / "№" / "N" или просто пробелы.
    SERIES_NUMBER_RE = /\b(\d{2}\s?\d{2})\s*(?:№|номер|N\.?)?\s*(\d{6})\b/i.freeze
    ISSUER_CODE_RE   = /(\d{3}-\d{3})/.freeze

    def extract
      result = {}

      if (m = @text.match(SERIES_NUMBER_RE))
        series = m[1].gsub(/\s+/, "")
        number = m[2]
        result["number"] = "#{series[0..1]} #{series[2..3]} #{number}"
      end

      issuer_block = @text.match(/выдан\s*[:.]?\s*([^\n]{5,200})/i)&.[](1)
      result["issuer"] = issuer_block.strip if issuer_block

      if (m = @text.match(/код[\s\-_]*подразделения[:\s\-]*#{ISSUER_CODE_RE.source}/i))
        result["issuer_code"] = m[1]
      end

      dates = find_all_dates
      if dates.any?
        # эвристика: первая дата обычно "Дата выдачи"
        result["issued_at"] = dates.first.to_s
        # вторая встречается как "Дата рождения" или "Действителен до"
        result["birth_date"] = dates[1].to_s if dates.size > 1
      end

      result.compact
    end
  end
end
