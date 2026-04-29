# Привязываем seeded users к employees + создаём ещё немного синтетических.

require "faker"
Faker::Config.locale = "ru"

dept = ->(code) { Department.find_by!(company: $company, code: code) }
pos  = ->(code) { Position.find_by!(company: $company, code: code) }
grd  = ->(level) { Grade.find_by!(company: $company, level: level) }

linked_employees = [
  { user_email: "admin@hrms.local",   pn: "EMP001", last: "Бобков",   first: "Вадим",   middle: "Александрович", dept: "ROOT",     pos: "CEO",        grade: 5, hired: 5.years.ago.to_date, manager_pn: nil },
  { user_email: "hr@hrms.local",      pn: "EMP002", last: "Морозова", first: "Анна",    middle: "Сергеевна",     dept: "HR",       pos: "HR_SPEC",    grade: 3, hired: 3.years.ago.to_date, manager_pn: "EMP001" },
  { user_email: "manager@hrms.local", pn: "EMP003", last: "Лебедев",  first: "Олег",    middle: "Игоревич",      dept: "ENG",      pos: "PM",         grade: 4, hired: 4.years.ago.to_date, manager_pn: "EMP001" },
  { user_email: "alice@hrms.local",   pn: "EMP004", last: "Зайцева",  first: "Мария",   middle: "Викторовна",    dept: "ENG_BACK", pos: "DEV_BACK",   grade: 2, hired: 1.year.ago.to_date,  manager_pn: "EMP003" }
]

linked_employees.each do |row|
  user = User.find_by!(email: row[:user_email])
  manager = row[:manager_pn] && Employee.find_by(personnel_number: row[:manager_pn])
  emp = Employee.find_or_initialize_by(company: $company, personnel_number: row[:pn])
  emp.assign_attributes(
    user:         user,
    last_name:    row[:last],
    first_name:   row[:first],
    middle_name:  row[:middle],
    department:   dept.call(row[:dept]),
    position:     pos.call(row[:pos]),
    grade:        grd.call(row[:grade]),
    manager:      manager,
    birth_date:   Faker::Date.birthday(min_age: 24, max_age: 50),
    gender:       :male,
    phone:        Faker::PhoneNumber.cell_phone,
    personal_email: Faker::Internet.email,
    hired_at:     row[:hired],
    employment_type: :full_time,
    state:        :active
  )
  emp.save!
end

# Глава отдела HR — Анна, разработки — Олег.
Department.find_by!(company: $company, code: "HR").update!(head_employee_id: Employee.find_by(personnel_number: "EMP002").id)
Department.find_by!(company: $company, code: "ENG").update!(head_employee_id: Employee.find_by(personnel_number: "EMP003").id)

# 16 синтетических сотрудников (без user-аккаунта)
ceo = Employee.find_by(personnel_number: "EMP001")
hr  = Employee.find_by(personnel_number: "EMP002")
pm  = Employee.find_by(personnel_number: "EMP003")

synthetic = [
  { dept: "ENG_BACK",  pos: "DEV_BACK",   grade: 3, manager: pm,  gender: :male },
  { dept: "ENG_BACK",  pos: "DEV_BACK",   grade: 1, manager: pm,  gender: :female },
  { dept: "ENG_FRONT", pos: "DEV_FRONT",  grade: 3, manager: pm,  gender: :male },
  { dept: "ENG_FRONT", pos: "DEV_FRONT",  grade: 2, manager: pm,  gender: :female },
  { dept: "ENG_QA",    pos: "QA_ENG",     grade: 2, manager: pm,  gender: :male },
  { dept: "ENG_QA",    pos: "QA_ENG",     grade: 1, manager: pm,  gender: :female },
  { dept: "PRODUCT",   pos: "PRODUCT_O",  grade: 4, manager: ceo, gender: :female },
  { dept: "PRODUCT",   pos: "DESIGNER",   grade: 3, manager: ceo, gender: :male },
  { dept: "PRODUCT",   pos: "DESIGNER",   grade: 2, manager: ceo, gender: :female },
  { dept: "SALES",     pos: "SALES_MAN",  grade: 2, manager: ceo, gender: :male },
  { dept: "SALES",     pos: "SALES_MAN",  grade: 3, manager: ceo, gender: :female },
  { dept: "SALES",     pos: "SALES_MAN",  grade: 1, manager: ceo, gender: :male },
  { dept: "HR",        pos: "HR_SPEC",    grade: 2, manager: hr,  gender: :female },
  { dept: "FIN",       pos: "ACCOUNTANT", grade: 3, manager: ceo, gender: :female },
  { dept: "FIN",       pos: "ACCOUNTANT", grade: 2, manager: ceo, gender: :female },
  { dept: "ENG_BACK",  pos: "DEV_BACK",   grade: 4, manager: pm,  gender: :male, state: :probation }
]

synthetic.each_with_index do |row, i|
  pn = "EMP#{(100 + i + 1).to_s.rjust(3, '0')}"
  next if Employee.exists?(company_id: $company.id, personnel_number: pn)

  Employee.create!(
    company:          $company,
    personnel_number: pn,
    last_name:        row[:gender] == :female ? Faker::Name.last_name + "а" : Faker::Name.last_name,
    first_name:       row[:gender] == :female ? Faker::Name.female_first_name : Faker::Name.male_first_name,
    middle_name:      Faker::Name.middle_name,
    department:       dept.call(row[:dept]),
    position:         pos.call(row[:pos]),
    grade:            grd.call(row[:grade]),
    manager:          row[:manager],
    birth_date:       Faker::Date.birthday(min_age: 21, max_age: 55),
    gender:           row[:gender],
    phone:            Faker::PhoneNumber.cell_phone,
    personal_email:   Faker::Internet.email,
    hired_at:         Faker::Date.between(from: 5.years.ago, to: 2.months.ago),
    employment_type:  :full_time,
    state:            row[:state] || :active
  )
end

puts "[seed] employees: #{Employee.count} total, #{Employee.state_active.count} active"
