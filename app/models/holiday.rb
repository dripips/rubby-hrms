class Holiday < ApplicationRecord
  belongs_to :company

  validates :date, :name, presence: true
  validates :date, uniqueness: { scope: %i[company_id region] }
end
