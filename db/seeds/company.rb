company = Company.find_or_create_by!(code: "DEMO") do |c|
  c.name              = "Rubby Industries"
  c.legal_name        = 'ООО "Раби Индастриз"'
  c.inn               = "7707083893"
  c.kpp               = "770701001"
  c.country           = "RU"
  c.default_currency  = "RUB"
  c.default_locale    = "ru"
  c.default_time_zone = "Moscow"
  c.address           = "г. Москва, Пресненская наб., 12"
  c.phone             = "+7 (495) 123-45-67"
  c.email             = "info@rubby.local"
end

puts "[seed] company: #{company.name} (id=#{company.id})"
$company = company
