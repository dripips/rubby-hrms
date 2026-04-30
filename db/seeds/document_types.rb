# Базовые типы документов сотрудников. Идемпотентно: ищется по
# (company, code), обновляется при изменении.

company = Company.kept.first
return unless company

DOCUMENT_TYPES = [
  # Удостоверения личности
  { code: "passport_ru",    name: "Паспорт РФ",            extractor_kind: "passport", icon: "🪪", required: true,  default_validity_months: 240, sort_order: 10, description: "Внутренний паспорт гражданина РФ. Серия/номер, дата выдачи, орган." },
  { code: "passport_intl",  name: "Загранпаспорт",         extractor_kind: "passport", icon: "🛂", required: false, default_validity_months: 120, sort_order: 11, description: "Заграничный паспорт. Срок действия 5 или 10 лет." },
  { code: "snils",          name: "СНИЛС",                 extractor_kind: "snils",    icon: "🆔", required: true,  default_validity_months: nil, sort_order: 20, description: "Страховой номер индивидуального лицевого счёта. Бессрочный." },
  { code: "inn",            name: "ИНН",                   extractor_kind: "inn",      icon: "🔢", required: true,  default_validity_months: nil, sort_order: 21, description: "Идентификационный номер налогоплательщика. Бессрочный." },

  # Трудовые
  { code: "labor_contract", name: "Трудовой договор",      extractor_kind: "contract", icon: "📜", required: true,  default_validity_months: nil, sort_order: 30, description: "Основной трудовой договор. Стороны, период, должность, зарплата." },
  { code: "nda",            name: "NDA / Соглашение о неразглашении", extractor_kind: "nda", icon: "🤐", required: false, default_validity_months: 36, sort_order: 31, description: "Соглашение о неразглашении конфиденциальной информации." },
  { code: "additional_agreement", name: "Доп. соглашение", extractor_kind: "contract", icon: "📝", required: false, default_validity_months: nil, sort_order: 32, description: "Дополнительное соглашение к трудовому договору (повышение, перевод и т.п.)." },

  # Образование
  { code: "diploma",        name: "Диплом об образовании", extractor_kind: "diploma", icon: "🎓", required: false, default_validity_months: nil, sort_order: 40, description: "Диплом ВУЗа или среднего проф. образования." },
  { code: "certificate",    name: "Сертификат / Курсы",    extractor_kind: "free",    icon: "📄", required: false, default_validity_months: 36,  sort_order: 41, description: "Сертификаты о прохождении курсов, тренингов, сдаче экзаменов." },

  # Медицина и допуски
  { code: "medical_book",   name: "Медицинская книжка",    extractor_kind: "medical", icon: "🩺", required: false, default_validity_months: 12,  sort_order: 50, description: "Личная медицинская книжка. Обновляется ежегодно." },
  { code: "vaccination",    name: "Сертификат о прививках", extractor_kind: "free",   icon: "💉", required: false, default_validity_months: 12,  sort_order: 51, description: "Подтверждение вакцинации (грипп, ковид и т.п.)." },

  # Прочие
  { code: "driving_license", name: "Водительское удостоверение", extractor_kind: "free", icon: "🚗", required: false, default_validity_months: 120, sort_order: 60, description: "Если работа связана с управлением ТС." },
  { code: "visa_work",       name: "Рабочая виза",         extractor_kind: "free",     icon: "🌍", required: false, default_validity_months: 12,  sort_order: 61, description: "Для иностранных сотрудников." },
  { code: "other",           name: "Прочее",               extractor_kind: "free",     icon: "📎", required: false, default_validity_months: nil, sort_order: 99, description: "Любые другие документы." }
].freeze

DOCUMENT_TYPES.each do |attrs|
  type = DocumentType.find_or_initialize_by(company: company, code: attrs[:code])
  type.assign_attributes(attrs.merge(active: true))
  type.save!
end

puts "[seeds] document_types: #{DocumentType.kept.count}"
