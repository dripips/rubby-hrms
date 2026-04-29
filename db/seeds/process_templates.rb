# Дефолтные шаблоны онбординга/офбординга. Идемпотентны: ищем по
# (company, kind, name); если уже есть — обновляем items.

company = Company.kept.first
return unless company

ONBOARDING_DEFAULT = [
  { title: "Подписать трудовой договор и NDA",  kind: "paperwork", due_offset_days: 0,  description: "Все документы оформляются HR в первый день." },
  { title: "Выдать ноутбук и периферию",         kind: "equipment", due_offset_days: 0,  description: "IT передаёт оборудование, инвентарный номер вносится в учётную систему." },
  { title: "Завести корпоративную почту и Slack", kind: "access",   due_offset_days: 0,  description: "Базовый набор аккаунтов с временным паролем." },
  { title: "Welcome-встреча с руководителем",    kind: "intro",     due_offset_days: 1,  description: "Знакомство, цели на испытательный срок, ожидания." },
  { title: "Знакомство с командой (lunch / call)", kind: "intro",   due_offset_days: 1 },
  { title: "Тур с наставником по продукту/коду", kind: "intro",     due_offset_days: 3 },
  { title: "Обучение: Security & Code of Conduct", kind: "training", due_offset_days: 7,  description: "Обязательные курсы по безопасности и корпоративной этике." },
  { title: "1-week check-in с руководителем",    kind: "checkin",   due_offset_days: 7 },
  { title: "30-day check-in",                    kind: "checkin",   due_offset_days: 30 },
  { title: "60-day check-in",                    kind: "checkin",   due_offset_days: 60 },
  { title: "Probation review (90 дней)",         kind: "checkin",   due_offset_days: 90, description: "Итоговая оценка испытательного срока, решение о продлении/завершении." }
].freeze

OFFBOARDING_DEFAULT = [
  { title: "План передачи знаний (KT plan)",     kind: "kt_session",       due_offset_days: 14, description: "Какие зоны ответственности у сотрудника, кому что передать, в каких сессиях." },
  { title: "Описание текущих проектов в Confluence", kind: "paperwork",   due_offset_days: 10 },
  { title: "KT-сессия 1: команда",               kind: "kt_session",       due_offset_days: 7 },
  { title: "KT-сессия 2: код / процессы",        kind: "kt_session",       due_offset_days: 5 },
  { title: "Передача активных задач",            kind: "kt_session",       due_offset_days: 3 },
  { title: "Exit interview с HR",                kind: "exit_interview",   due_offset_days: 2 },
  { title: "Прощальное письмо команде",          kind: "farewell",         due_offset_days: 1 },
  { title: "Возврат оборудования",               kind: "equipment_return", due_offset_days: 0 },
  { title: "Отзыв доступов (Slack/email/git)",   kind: "access_revoke",    due_offset_days: 0 },
  { title: "Финальная зарплата + расчётные",     kind: "paperwork",        due_offset_days: -1 }
].freeze

[
  { kind: "onboarding",  name: "Стандартный онбординг",  items: ONBOARDING_DEFAULT,  description: "Базовый чек-лист первого дня + check-in'ы 1/30/60/90 дней." },
  { kind: "offboarding", name: "Стандартный офбординг", items: OFFBOARDING_DEFAULT, description: "Полный цикл от плана KT до возврата оборудования и доступов." }
].each.with_index do |attrs, idx|
  pt = ProcessTemplate.find_or_initialize_by(company: company, kind: attrs[:kind], name: attrs[:name])
  pt.assign_attributes(
    description:      attrs[:description],
    items:            attrs[:items].map(&:stringify_keys),
    default_template: true,
    active:           true,
    position:         idx
  )
  pt.save!
end

puts "[seeds] process_templates: #{ProcessTemplate.kept.count}"
