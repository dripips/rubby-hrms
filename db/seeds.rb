# Idempotent dev seeds. Safe to run multiple times.

# Languages first — они нужны раньше всего для I18n.
load Rails.root.join("db", "seeds", "languages.rb").to_s

# Затем компания → структура → справочники → сотрудники.
load Rails.root.join("db", "seeds", "company.rb").to_s
load Rails.root.join("db", "seeds", "departments.rb").to_s
load Rails.root.join("db", "seeds", "positions_and_grades.rb").to_s
load Rails.root.join("db", "seeds", "leave_types.rb").to_s
load Rails.root.join("db", "seeds", "employees.rb").to_s
load Rails.root.join("db", "seeds", "recruitment.rb").to_s
load Rails.root.join("db", "seeds", "kpi.rb").to_s
load Rails.root.join("db", "seeds", "leave_approval_rules.rb").to_s
load Rails.root.join("db", "seeds", "process_templates.rb").to_s
load Rails.root.join("db", "seeds", "processes.rb").to_s

users = [
  { email: "admin@hrms.local",   password: "password123", role: :superadmin },
  { email: "hr@hrms.local",      password: "password123", role: :hr },
  { email: "manager@hrms.local", password: "password123", role: :manager },
  { email: "alice@hrms.local",   password: "password123", role: :employee }
]

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
