# Server-side lock for in-flight AI tasks.
#
# Scope strings encode the subject of the task:
#   "applicant:42", "round:7", "opening:3", "employee:11",
#   "kpi_team:company:1", "kpi_team:department:5", "kpi_team:manager:9"
#
# Backed by Rails.cache with a 5-minute TTL so a crashed worker cannot
# leave the UI permanently blocked.
class AiLock
  TTL = 5.minutes

  class << self
    def lock!(scope, kind:)
      Rails.cache.write(key(scope), { kind: kind, ts: Time.current.to_i }, expires_in: TTL)
    end

    def unlock!(scope)
      Rails.cache.delete(key(scope))
    end

    def running?(scope)
      Rails.cache.read(key(scope)).present?
    end

    def kind_for(scope)
      Rails.cache.read(key(scope))&.dig(:kind)
    end

    def for_applicant(applicant)  = "applicant:#{applicant.is_a?(Integer) ? applicant : applicant.id}"
    def for_round(round)          = "round:#{round.is_a?(Integer) ? round : round.id}"
    def for_opening(opening)      = "opening:#{opening.is_a?(Integer) ? opening : opening.id}"
    def for_employee(employee)    = "employee:#{employee.is_a?(Integer) ? employee : employee.id}"
    def for_kpi_team(scope_type:, scope_id: nil)
      "kpi_team:#{scope_type}:#{scope_id.presence || 'all'}"
    end

    def for_onboarding(p)  = "onboarding:#{p.is_a?(Integer) ? p : p.id}"
    def for_offboarding(p) = "offboarding:#{p.is_a?(Integer) ? p : p.id}"

    # Broadcasts a re-render of the controls block for the given scope so
    # buttons in every open tab reflect the current lock state. Kind is the
    # AI task that just started (or nil to render the unlocked state).
    def broadcast_controls(scope)
      head, *rest = scope.split(":")
      case head
      when "applicant"   then broadcast_applicant_controls(rest.first.to_i)
      when "round"       then broadcast_round_controls(rest.first.to_i)
      when "opening"     then broadcast_opening_controls(rest.first.to_i)
      when "employee"    then broadcast_employee_controls(rest.first.to_i)
      when "kpi_team"    then broadcast_kpi_team_controls(*rest)
      when "onboarding"  then broadcast_onboarding_controls(rest.first.to_i)
      when "offboarding" then broadcast_offboarding_controls(rest.first.to_i)
      end
    rescue StandardError => e
      Rails.logger.warn("[AiLock#broadcast_controls] #{scope}: #{e.class}: #{e.message}")
    end

    private

    def key(scope) = "ai:running:#{scope}"

    def broadcast_applicant_controls(id)
      applicant = JobApplicant.kept.find_by(id: id) or return
      Turbo::StreamsChannel.broadcast_replace_to(
        [ applicant, "ai_panel" ],
        target:  "ai-controls-applicant-#{applicant.id}",
        partial: "ai/applicants/controls",
        locals:  { applicant: applicant }
      )
    end

    def broadcast_round_controls(id)
      round = InterviewRound.kept.find_by(id: id) or return
      Turbo::StreamsChannel.broadcast_replace_to(
        [ round, "ai_questions" ],
        target:  "ai-controls-round-#{round.id}",
        partial: "ai/rounds/controls",
        locals:  { round: round }
      )
    end

    def broadcast_opening_controls(id)
      opening = JobOpening.kept.find_by(id: id) or return
      Turbo::StreamsChannel.broadcast_replace_to(
        [ opening, "ai_compare" ],
        target:  "ai-controls-opening-#{opening.id}",
        partial: "ai/openings/controls",
        locals:  { opening: opening }
      )
    end

    def broadcast_employee_controls(id)
      employee = Employee.kept.find_by(id: id) or return
      Turbo::StreamsChannel.broadcast_replace_to(
        [ employee, "ai_leaves" ],
        target:  "ai-controls-employee-#{employee.id}",
        partial: "ai/leaves/controls",
        locals:  { employee: employee }
      )
    end

    def broadcast_onboarding_controls(id)
      process = OnboardingProcess.kept.find_by(id: id) or return
      Turbo::StreamsChannel.broadcast_replace_to(
        [ process, "ai_panel" ],
        target:  "ai-controls-onboarding-#{process.id}",
        partial: "ai/onboarding/controls",
        locals:  { process: process }
      )
    end

    def broadcast_offboarding_controls(id)
      process = OffboardingProcess.kept.find_by(id: id) or return
      Turbo::StreamsChannel.broadcast_replace_to(
        [ process, "ai_panel" ],
        target:  "ai-controls-offboarding-#{process.id}",
        partial: "ai/offboarding/controls",
        locals:  { process: process }
      )
    end

    def broadcast_kpi_team_controls(scope_type, scope_id)
      company_id = Company.kept.first&.id or return
      Turbo::StreamsChannel.broadcast_replace_to(
        [ "company-#{company_id}", "kpi_team" ],
        target:  "ai-controls-kpi-team",
        partial: "ai/kpi/controls",
        locals:  { scope_type: scope_type, scope_id: scope_id == "all" ? nil : scope_id }
      )
    end
  end
end
