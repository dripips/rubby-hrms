[
  { code: "ANNUAL",     name: "Ежегодный отпуск",         paid: true,  requires_doc: false, default_days_per_year: 28, color: "#34C759", sort_order: 1 },
  { code: "UNPAID",     name: "Без сохранения заработка", paid: false, requires_doc: false, default_days_per_year: 0,  color: "#8E8E93", sort_order: 2 },
  { code: "SICK",       name: "Больничный",               paid: true,  requires_doc: true,  default_days_per_year: 0,  color: "#FF9500", sort_order: 3 },
  { code: "MATERNITY",  name: "Декретный отпуск",         paid: true,  requires_doc: true,  default_days_per_year: 140, color: "#AF52DE", sort_order: 4 },
  { code: "STUDY",      name: "Учебный отпуск",           paid: true,  requires_doc: true,  default_days_per_year: 14,  color: "#5856D6", sort_order: 5 },
  { code: "CHILD_CARE", name: "По уходу за ребёнком",     paid: false, requires_doc: true,  default_days_per_year: 0,   color: "#FF2D55", sort_order: 6 }
].each do |attrs|
  LeaveType.find_or_create_by!(company: $company, code: attrs[:code]) do |t|
    t.assign_attributes(attrs)
  end
end

puts "[seed] leave_types: #{LeaveType.count}"
