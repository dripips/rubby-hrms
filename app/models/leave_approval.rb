class LeaveApproval < ApplicationRecord
  belongs_to :leave_request
  belongs_to :approver, class_name: "User"

  enum :step,     { manager: 0, hr: 1 }, prefix: true
  enum :decision, { pending: 0, approved: 1, rejected: 2 }, prefix: :decision

  validates :leave_request_id, uniqueness: { scope: :step }
end
