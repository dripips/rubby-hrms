# Универсальный механизм отображения / редактирования custom fields,
# определённых в Dictionary (kind=field_schema). Работает для любой модели,
# у которой есть jsonb-колонка с под-хешем "_custom".
#
# Использование во view:
#   <%= render_custom_fields_inputs(form, target_model: "DocumentType",
#                                          target_scope: doc.document_type_id,
#                                          values: doc.extracted_data["_custom"]) %>
#   <%= render_custom_field_values(@doc.extracted_data["_custom"],
#                                  target_model: "DocumentType",
#                                  target_scope: @doc.document_type_id) %>
module CustomFieldsHelper
  # Возвращает options-pairs для f.select из lookup-словаря компании. Если
  # словарь не найден или пуст — возвращает fallback (например, статичный
  # хардкод из view). Это позволяет ВВОДИТЬ кастомизацию инкрементально:
  # компания, которая ничего не настроила, видит дефолты; та, что добавила
  # свой Dictionary lookup — видит свои значения.
  #
  # Использование:
  #   <%= f.select :source, lookup_options_for("applicant_sources",
  #         fallback: %w[manual hh linkedin referral].map { |s| [t("..#{s}"), s] }) %>
  def lookup_options_for(code, fallback: nil)
    @lookup_cache ||= {}
    return @lookup_cache[code] if @lookup_cache.key?(code)

    company = Company.kept.first
    return @lookup_cache[code] = (fallback || []) unless company

    dict = Dictionary.lookups.kept.where(company: company, code: code).first
    if dict
      entries = dict.entries.active.to_a
      return @lookup_cache[code] = entries.map { |e| [ e.value, e.key ] } if entries.any?
    end
    @lookup_cache[code] = fallback || []
  end

  # Возвращает kept-entries field_schema-словаря для данного scope, или [].
  # Кэшируем по (company_id, code) на запрос — partial может вызываться много раз.
  def custom_field_entries(target_model:, target_scope:)
    @custom_field_cache ||= {}
    company = Company.kept.first
    return [] unless company

    code = "#{target_model}:#{target_scope}"
    @custom_field_cache[code] ||= begin
      schema = Dictionary.field_schemas.kept.where(company: company, code: code).first
      schema&.entries&.kept&.where(active: true)&.order(:sort_order, :value)&.to_a || []
    end
  end

  # Рендерит инпуты в существующий form_builder. Имя поля строится так,
  # чтобы попасть в params под ключом custom_fields[<key>].
  def render_custom_fields_inputs(form, target_model:, target_scope:, values: {})
    entries = custom_field_entries(target_model: target_model, target_scope: target_scope)
    return "" if entries.empty?

    values  = (values || {}).to_h.with_indifferent_access
    content_tag(:div, class: "custom-fields-section") do
      heading = content_tag(:h3, t("custom_fields.title", default: "Доп.поля компании"),
                             class: "title-3 mb-2")
      hint    = content_tag(:p, t("custom_fields.hint",
                                  default: "Определены в Справочниках. Изменить набор полей: Настройки → Справочники."),
                             class: "footnote text-tertiary mb-3")
      inputs  = entries.map { |e| custom_field_input_for(form, e, values[e.key]) }.join.html_safe
      heading + hint + content_tag(:div, inputs, class: "row g-3")
    end
  end

  # Рендерит значения custom-полей для read-only show-страницы.
  def render_custom_field_values(values, target_model:, target_scope:)
    entries = custom_field_entries(target_model: target_model, target_scope: target_scope)
    return "" if entries.empty?

    values = (values || {}).to_h.with_indifferent_access
    rows = entries.filter_map do |e|
      v = values[e.key]
      next if v.blank? && v != false
      content_tag(:div, class: "process-facts__cell") do
        content_tag(:span, e.value, class: "process-facts__label") +
          content_tag(:span, format_custom_field_value(e, v), class: "process-facts__value")
      end
    end
    return "" if rows.empty?

    heading = content_tag(:h3, t("custom_fields.title", default: "Доп.поля компании"),
                           class: "title-3 mb-3")
    body    = content_tag(:div, rows.join.html_safe, class: "process-facts")
    content_tag(:div, heading + body, class: "card-apple mt-3")
  end

  private

  def custom_field_input_for(form, entry, value)
    base_name  = "custom_fields[#{entry.key}]"
    label      = entry.value
    hint       = entry.field_hint.presence
    required   = entry.field_required
    col_class  = (entry.field_type == "textarea" ? "col-md-12" : "col-md-6")

    input = case entry.field_type
            when "string"
              text_field_tag(base_name, value.to_s, class: "form-control", required: required)
            when "textarea"
              text_area_tag(base_name, value.to_s, class: "form-control", rows: 3, required: required)
            when "integer"
              number_field_tag(base_name, value, class: "form-control", required: required, step: 1)
            when "decimal"
              number_field_tag(base_name, value, class: "form-control", required: required, step: "0.01")
            when "date"
              date_field_tag(base_name, value.to_s, class: "form-control", required: required)
            when "boolean"
              hidden = hidden_field_tag(base_name, "false")
              check  = check_box_tag(base_name, "true",
                                      ActiveModel::Type::Boolean.new.cast(value),
                                      class: "form-check-input")
              hidden + content_tag(:div, check + " " + label_tag(base_name, label, class: "form-check-label"),
                                   class: "form-check")
            when "select"
              opts = options_for_select(entry.field_options.map { |o| [ o, o ] }, value)
              select_tag(base_name, opts, class: "form-select", include_blank: !required, required: required)
            else
              text_field_tag(base_name, value.to_s, class: "form-control")
            end

    label_html = entry.field_type == "boolean" ? "" : label_tag(base_name, label, class: "form-label")
    hint_html  = hint ? content_tag(:p, hint, class: "form-text") : ""
    content_tag(:div, "#{label_html}#{input}#{hint_html}".html_safe, class: col_class)
  end

  def format_custom_field_value(entry, value)
    case entry.field_type
    when "boolean" then value ? "✓" : "—"
    when "date"
      d = (value.is_a?(Date) ? value : (Date.parse(value.to_s) rescue nil))
      d ? l(d, format: :long) : value.to_s
    else value.to_s
    end
  end
end
