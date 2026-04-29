class ApplicationStageChange < ApplicationRecord
  belongs_to :job_applicant
  belongs_to :user

  validates :to_stage, :changed_at, presence: true

  scope :recent, -> { order(changed_at: :desc) }
end
