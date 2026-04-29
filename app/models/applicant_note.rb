class ApplicantNote < ApplicationRecord
  include Discard::Model

  belongs_to :job_applicant
  belongs_to :author, class_name: "User"

  validates :body, presence: true

  scope :recent, -> { kept.order(created_at: :desc) }
end
