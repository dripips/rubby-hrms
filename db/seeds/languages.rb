[
  { code: "ru", native_name: "Русский", english_name: "Russian", flag: "ru", is_default: true,  enabled: true, position: 1 },
  { code: "en", native_name: "English", english_name: "English", flag: "gb", is_default: false, enabled: true, position: 2 },
  { code: "de", native_name: "Deutsch", english_name: "German",  flag: "de", is_default: false, enabled: true, position: 3 }
].each do |attrs|
  lang = Language.find_or_initialize_by(code: attrs[:code])
  lang.assign_attributes(attrs)
  lang.save!
end

puts "[seed] languages: total=#{Language.count} enabled=#{Language.enabled.count} default=#{Language.default&.code}"
