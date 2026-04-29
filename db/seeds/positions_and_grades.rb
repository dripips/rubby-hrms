positions = [
  { code: "DEV_BACK",   name: "Бэкенд-разработчик",     category: "Engineering" },
  { code: "DEV_FRONT",  name: "Фронтенд-разработчик",   category: "Engineering" },
  { code: "QA_ENG",     name: "QA-инженер",             category: "Engineering" },
  { code: "PM",         name: "Менеджер проектов",      category: "Product" },
  { code: "PRODUCT_O",  name: "Владелец продукта",      category: "Product" },
  { code: "DESIGNER",   name: "Дизайнер",               category: "Design" },
  { code: "SALES_MAN",  name: "Менеджер по продажам",   category: "Sales" },
  { code: "HR_SPEC",    name: "HR-специалист",          category: "HR" },
  { code: "ACCOUNTANT", name: "Бухгалтер",              category: "Finance" },
  { code: "CEO",        name: "Генеральный директор",   category: "Leadership" }
].each_with_index do |attrs, i|
  Position.find_or_create_by!(company: $company, code: attrs[:code]) do |p|
    p.name       = attrs[:name]
    p.category   = attrs[:category]
    p.sort_order = i
  end
end

[
  { level: 1, name: "Junior",            min_salary: 60_000,  max_salary: 100_000 },
  { level: 2, name: "Middle",            min_salary: 100_000, max_salary: 180_000 },
  { level: 3, name: "Senior",            min_salary: 180_000, max_salary: 280_000 },
  { level: 4, name: "Lead / Principal",  min_salary: 280_000, max_salary: 450_000 },
  { level: 5, name: "Director",          min_salary: 450_000, max_salary: 800_000 }
].each do |attrs|
  Grade.find_or_create_by!(company: $company, level: attrs[:level]) do |g|
    g.name       = attrs[:name]
    g.min_salary = attrs[:min_salary]
    g.max_salary = attrs[:max_salary]
    g.currency   = "RUB"
  end
end

puts "[seed] positions=#{Position.count} grades=#{Grade.count}"
