# Runs daily — flips approved leaves into active state on their start date,
# and active leaves into completed on the day after they end. Idempotent:
# requests outside the matching ranges are ignored.
class LeaveLifecycleJob < ApplicationJob
  queue_as :default

  def perform
    today = Date.current

    activate_count = 0
    LeaveRequest.kept.where(state: "hr_approved")
                .where("started_on <= ?", today)
                .find_each do |req|
      req.start! if req.may_start?
      activate_count += 1
    end

    complete_count = 0
    LeaveRequest.kept.where(state: "active")
                .where("ended_on < ?", today)
                .find_each do |req|
      req.complete! if req.may_complete?
      complete_count += 1
    end

    Rails.logger.info("[LeaveLifecycleJob] activated=#{activate_count} completed=#{complete_count}")
  end
end
