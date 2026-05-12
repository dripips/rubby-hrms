# Idempotent dev seeds. Safe to run multiple times.

# Languages first — они нужны раньше всего для I18n.
load Rails.root.join("db", "seeds", "languages.rb").to_s

# Company перед users — для company-scoped FK (хотя у User'а её нет напрямую,
# но employees.rb ниже сразу ищет users по email).
load Rails.root.join("db", "seeds", "company.rb").to_s

# Users создаются ДО employees.rb — иначе employees.rb падает с
# User.find_by!(email: ...) RecordNotFound на свежей БД.
# В development / test засеиваем фиксированный пароль "password123" чтобы
# dev-юзеры могли логиниться + smoke-spec мог логиниться в CI. В production
# этот код запускается только если БД пустая — для каждого юзера генерируется
# случайный пароль и логируется.
default_password = (Rails.env.development? || Rails.env.test?) ? "password123" : SecureRandom.alphanumeric(20)

users = [
  { email: "admin@hrms.local",   password: default_password, role: :superadmin },
  { email: "hr@hrms.local",      password: default_password, role: :hr },
  { email: "manager@hrms.local", password: default_password, role: :manager },
  { email: "alice@hrms.local",   password: default_password, role: :employee }
]
puts "[seed] default password for fresh seed users: #{default_password}" unless Rails.env.development?

created = 0
updated = 0

users.each do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  is_new = user.new_record?
  user.password = attrs[:password] if is_new
  user.role = attrs[:role]
  user.locale = "ru"
  user.time_zone = "Moscow"
  user.save!
  is_new ? (created += 1) : (updated += 1)
  Rails.logger.info("[seed] user #{attrs[:role]} #{user.email} (#{is_new ? 'created' : 'updated'})")
end

puts "[seed] users: created=#{created} updated=#{updated} total=#{User.count}"

# Структура → справочники → сотрудники → найм → KPI → отпуска → процессы → документы.
load Rails.root.join("db", "seeds", "departments.rb").to_s
load Rails.root.join("db", "seeds", "positions_and_grades.rb").to_s
load Rails.root.join("db", "seeds", "leave_types.rb").to_s
load Rails.root.join("db", "seeds", "employees.rb").to_s
load Rails.root.join("db", "seeds", "recruitment.rb").to_s
load Rails.root.join("db", "seeds", "kpi.rb").to_s
load Rails.root.join("db", "seeds", "leave_approval_rules.rb").to_s
load Rails.root.join("db", "seeds", "process_templates.rb").to_s
load Rails.root.join("db", "seeds", "processes.rb").to_s
load Rails.root.join("db", "seeds", "document_types.rb").to_s
