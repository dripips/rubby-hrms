class EmployeeChild < ApplicationRecord
  include Discard::Model
  include Auditable

  belongs_to :employee
  belongs_to :gender_record, class_name: "Gender", foreign_key: :gender_ref_id, optional: true

  validates :first_name, :birth_date, presence: true

  scope :ordered, -> { kept.order(:birth_date) }

  def age
    return nil if birth_date.nil?
    today = Date.current
    a = today.year - birth_date.year
    a -= 1 if today < birth_date + a.years
    a
  end

  def upcoming_birthday
    return nil if birth_date.nil?
    today = Date.current
    this_year = birth_date.change(year: today.year)
    this_year >= today ? this_year : this_year.next_year
  end
end
