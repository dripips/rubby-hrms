root = Department.find_or_create_by!(company: $company, code: "ROOT", parent: nil) do |d|
  d.name = "Главный офис"
end

[
  { code: "ENG",     name: "Разработка",          parent: root },
  { code: "PRODUCT", name: "Продукт",             parent: root },
  { code: "SALES",   name: "Продажи",             parent: root },
  { code: "HR",      name: "HR",                  parent: root },
  { code: "FIN",     name: "Финансы",             parent: root }
].each do |attrs|
  Department.find_or_create_by!(company: $company, code: attrs[:code]) do |d|
    d.name = attrs[:name]
    d.parent = attrs[:parent]
  end
end

# Подотделы внутри Разработки
eng = Department.find_by!(company: $company, code: "ENG")
[
  { code: "ENG_BACK",  name: "Бэкенд",     parent: eng },
  { code: "ENG_FRONT", name: "Фронтенд",   parent: eng },
  { code: "ENG_QA",    name: "QA",         parent: eng }
].each do |attrs|
  Department.find_or_create_by!(company: $company, code: attrs[:code]) do |d|
    d.name = attrs[:name]
    d.parent = attrs[:parent]
  end
end

puts "[seed] departments: total=#{Department.count}"
