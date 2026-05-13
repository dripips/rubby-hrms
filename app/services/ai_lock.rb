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
      read_lock(scope).present?
    end

    def kind_for(scope)
      read_lock(scope)&.dig(:kind)
    end

    def for_applicant(applicant)  = "applicant:#{id_for(applicant)}"
    def for_round(round)          = "round:#{id_for(round)}"
    def for_opening(opening)      = "opening:#{id_for(opening)}"
    def for_employee(employee)    = "employee:#{id_for(employee)}"
    def for_onboarding(process)   = "onboarding:#{id_for(process)}"
    def for_offboarding(process)  = "offboarding:#{id_for(process)}"
    def for_document(document)    = "document:#{id_for(document)}"
    def for_dictionary(dictionary) = "dictionary:#{id_for(dictionary)}"
    def for_company_bootstrap(company) = "company_bootstrap:#{id_for(company)}"

    def for_kpi_team(scope_type:, scope_id: nil)
      "kpi_team:#{scope_type}:#{scope_id.presence || 'all'}"
    end

    # Re-renders the controls block for the given scope so buttons in every
    # open tab reflect the current lock state. Dispatch by scope prefix.
    def broadcast_controls(scope)
      head, *rest = scope.split(":")
      handler = CONTROL_BROADCASTERS[head]
      return unless handler

      send(handler, *rest)
    rescue StandardError => e
      Rails.logger.warn("[AiLock#broadcast_controls] #{scope}: #{e.class}: #{e.message}")
    end

    private

    CONTROL_BROADCASTERS = {
      "applicant"   => :broadcast_applicant_controls,
      "round"       => :broadcast_round_controls,
      "opening"     => :broadcast_opening_controls,
      "employee"    => :broadcast_employee_controls,
      "kpi_team"    => :broadcast_kpi_team_controls,
      "onboarding"  => :broadcast_onboarding_controls,
      "offboarding" => :broadcast_offboarding_controls,
      "document"           => :broadcast_document_controls,
      "dictionary"         => :broadcast_dictionary_controls,
      "company_bootstrap"  => :broadcast_company_bootstrap_controls
    }.freeze

    def key(scope) = "ai:running:#{scope}"
    def read_lock(scope) = Rails.cache.read(key(scope))
    def id_for(obj)  = obj.is_a?(Integer) ? obj : obj.id

    def broadcast_applicant_controls(id, *)
      applicant = JobApplicant.kept.find_by(id: id.to_i) or return
      Turbo::StreamsChannel.broadcast_replace_to(
        [ applicant, "ai_panel" ],
        target:  "ai-controls-applicant-#{applicant.id}",
        partial: "ai/applicants/controls",
        locals:  { applicant: applicant }
      )
    end

    def broadcast_round_controls(id, *)
      round = InterviewRound.kept.find_by(id: id.to_i) or return
      Turbo::StreamsChannel.broadcast_replace_to(
        [ round, "ai_questions" ],
        target:  "ai-controls-round-#{round.id}",
        partial: "ai/rounds/controls",
        locals:  { round: round }
      )
    end

    def broadcast_opening_controls(id, *)
      opening = JobOpening.kept.find_by(id: id.to_i) or return
      Turbo::StreamsChannel.broadcast_replace_to(
        [ opening, "ai_compare" ],
        target:  "ai-controls-opening-#{opening.id}",
        partial: "ai/openings/controls",
        locals:  { opening: opening }
      )
    end

    def broadcast_employee_controls(id, *)
      employee = Employee.kept.find_by(id: id.to_i) or return
      Turbo::StreamsChannel.broadcast_replace_to(
        [ employee, "ai_leaves" ],
        target:  "ai-controls-employee-#{employee.id}",
        partial: "ai/leaves/controls",
        locals:  { employee: employee }
      )
    end

    def broadcast_onboarding_controls(id, *)
      process = OnboardingProcess.kept.find_by(id: id.to_i) or return
      Turbo::StreamsChannel.broadcast_replace_to(
        [ process, "ai_panel" ],
        target:  "ai-controls-onboarding-#{process.id}",
        partial: "ai/onboarding/controls",
        locals:  { process: process }
      )
    end

    def broadcast_offboarding_controls(id, *)
      process = OffboardingProcess.kept.find_by(id: id.to_i) or return
      Turbo::StreamsChannel.broadcast_replace_to(
        [ process, "ai_panel" ],
        target:  "ai-controls-offboarding-#{process.id}",
        partial: "ai/offboarding/controls",
        locals:  { process: process }
      )
    end

    def broadcast_document_controls(id, *)
      document = Document.kept.find_by(id: id.to_i) or return
      Turbo::StreamsChannel.broadcast_replace_to(
        [ document, "extraction" ],
        target:  "document-extraction-#{document.id}",
        partial: "documents/extraction_panel",
        locals:  { document: document }
      )
    end

    def broadcast_dictionary_controls(id, *)
      dictionary = Dictionary.kept.find_by(id: id.to_i) or return
      Turbo::StreamsChannel.broadcast_replace_to(
        [ dictionary, "ai_seed" ],
        target:  "dictionary-ai-#{dictionary.id}",
        partial: "settings/dictionaries/ai_panel",
        locals:  { dictionary: dictionary }
      )
    end

    def broadcast_company_bootstrap_controls(id, *)
      company = Company.kept.find_by(id: id.to_i) or return
      Turbo::StreamsChannel.broadcast_replace_to(
        [ company, "company_bootstrap" ],
        target:  "company-bootstrap",
        partial: "settings/dictionaries/bootstrap_panel",
        locals:  { company: company }
      )
    end

    def broadcast_kpi_team_controls(scope_type, scope_id, *)
      company_id = Current.company || Company.kept.first&.id or return
      Turbo::StreamsChannel.broadcast_replace_to(
        [ "company-#{company_id}", "kpi_team" ],
        target:  "ai-controls-kpi-team",
        partial: "ai/kpi/controls",
        locals:  { scope_type: scope_type, scope_id: scope_id == "all" ? nil : scope_id }
      )
    end
  end
end
