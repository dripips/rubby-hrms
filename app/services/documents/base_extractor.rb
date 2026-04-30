# Базовый класс для extractor'ов. Каждый специализированный потомок
# (PassportExtractor, SnilsExtractor и т.д.) реализует #extract и возвращает
# хеш с найденными полями. Если ничего не найдено — пустой хеш.
module Documents
  class BaseExtractor
    DATE_RE = /\b(\d{2})[.\/\-](\d{2})[.\/\-](\d{4})\b/.freeze

    def self.call(text)
      new(text).extract
    end

    def initialize(text)
      @text = text.to_s
      @lines = @text.split(/\r?\n/).map(&:strip).reject(&:empty?)
    end

    def extract
      raise NotImplementedError
    end

    private

    # Ищет первую дату в формате DD.MM.YYYY (или с / -). Возвращает Date или nil.
    def find_first_date(scope = @text)
      m = scope.match(DATE_RE)
      return nil unless m
      Date.new(m[3].to_i, m[2].to_i, m[1].to_i)
    rescue ArgumentError
      nil
    end

    def find_all_dates(scope = @text)
      scope.scan(DATE_RE).filter_map do |day, mon, year|
        Date.new(year.to_i, mon.to_i, day.to_i)
      rescue ArgumentError
        nil
      end
    end

    # Поиск значения по подписи: "Серия:" → следующий токен.
    def find_after_label(label_regex, value_regex = /\S+/)
      m = @text.match(/#{label_regex}\s*[:\-]?\s*(#{value_regex.source})/i)
      m ? m[1] : nil
    end
  end
end
