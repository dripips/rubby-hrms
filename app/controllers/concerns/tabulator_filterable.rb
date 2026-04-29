module TabulatorFilterable
  extend ActiveSupport::Concern

  NUMERIC_OPERATORS = {
    ">=" => ">=", "<=" => "<=", "<>" => "<>", "!=" => "<>",
    "==" => "=",  "="  => "=",  ">"  => ">",  "<"  => "<"
  }.freeze

  NUMERIC_RE = /\A(>=|<=|<>|!=|==|>|<|=)?\s*(-?\d+(?:[.,]\d+)?)\z/.freeze

  # Tabulator шлёт filter/sort как `filter[0][field]=...&filter[0][value]=...`,
  # Rails парсит это как hash {"0" => {...}}. Возвращаем массив hash'ей.
  def grid_array(raw)
    return [] if raw.blank?
    items = raw.respond_to?(:values) ? raw.values : Array(raw)
    items.map { |i| i.respond_to?(:permit!) ? i.permit!.to_h : i }.select { |i| i.is_a?(Hash) }
  end

  # Принимает строку вида ">3", ">=10", "<5", "=7", "<>0" или просто "5" (=).
  # Возвращает [oператор, число] или [nil, nil] если не парсится.
  def parse_numeric_filter(raw)
    s = raw.to_s.strip
    return [ nil, nil ] if s.empty?

    m = s.match(NUMERIC_RE)
    return [ nil, nil ] unless m

    op  = NUMERIC_OPERATORS[m[1] || "="]
    num = m[2].tr(",", ".")
    num = num.include?(".") ? num.to_f : num.to_i
    [ op, num ]
  end

  # Имя колонки должно быть простым identifier — защита от SQL injection.
  # `op` уже из whitelist (NUMERIC_OPERATORS), `num` параметризован через `?`.
  COLUMN_NAME_RE = /\A[a-z_][a-z0-9_]*\z/i.freeze

  def apply_numeric_compare(scope, column, raw)
    op, num = parse_numeric_filter(raw)
    return scope unless op
    return scope unless column.to_s =~ COLUMN_NAME_RE

    # column провалидирован regex'ом, op — whitelisted в NUMERIC_OPERATORS,
    # num параметризован через `?`. Arel.sql сообщает Brakeman, что мы знаем
    # что делаем — значение не из user input.
    quoted = scope.connection.quote_column_name(column)
    scope.where(Arel.sql("#{quoted} #{op} ?"), num)
  end

  # Удобный метод: собрать values: { id_string => label } из ActiveRecord-relation.
  def select_values_from(records, label: :name)
    records.each_with_object({}) { |r, h| h[r.id.to_s] = r.public_send(label).to_s }
  end
end
