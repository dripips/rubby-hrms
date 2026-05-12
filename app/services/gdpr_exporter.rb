# GDPR / 152-ФЗ Data Subject Access Request — собирает ВСЕ данные про юзера
# в один JSON. Юзер скачивает с /profile/export_data.
class GdprExporter
  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @user = user
    @employee = user.employee
  end

  def call
    {
      generated_at: Time.current.iso8601,
      generated_by: @user.email,
      account: account_data,
      profile: profile_data,
      employment: employment_data,
      documents: documents_data,
      leaves: leaves_data,
      kpi: kpi_data,
      interviews: interviews_data,
      notifications: notifications_data,
      ai_runs: ai_runs_data,
      audit_log: audit_log_data
    }
  end

  private

  def account_data
    {
      id: @user.id,
      email: @user.email,
      role: @user.role,
      locale: @user.locale,
      time_zone: @user.time_zone,
      created_at: @user.created_at&.iso8601,
      last_sign_in_at: @user.last_sign_in_at&.iso8601,
      sign_in_count: @user.sign_in_count,
      notification_preferences: @user.notification_preferences,
      dashboard_preferences: @user.dashboard_preferences
    }
  end

  def profile_data
    return nil unless @employee
    {
      full_name:    @employee.full_name,
      birth_date:   @employee.birth_date,
      gender:       @employee.gender,
      phone:        @employee.phone,
      personal_email: @employee.personal_email,
      address:      @employee.address,
      marital_status: @employee.marital_status,
      hobbies:      @employee.hobbies,
      shirt_size:   @employee.shirt_size,
      dietary_restrictions: @employee.dietary_restrictions,
      preferred_language:   @employee.preferred_language,
      emergency_contact_name:     @employee.emergency_contact_name,
      emergency_contact_phone:    @employee.emergency_contact_phone,
      emergency_contact_relation: @employee.emergency_contact_relation,
      has_disability: @employee.has_disability,
      special_needs: @employee.special_needs,
      custom_fields: @employee.custom_fields
    }
  end

  def employment_data
    return nil unless @employee
    {
      personnel_number: @employee.personnel_number,
      position:   @employee.position&.name,
      department: @employee.department&.name,
      grade:      @employee.grade&.name,
      manager:    @employee.manager&.full_name,
      hired_at:   @employee.hired_at,
      terminated_at: @employee.terminated_at,
      employment_type: @employee.employment_type,
      state: @employee.state
    }
  end

  def documents_data
    return [] unless @employee
    Document.where(documentable: @employee).map do |d|
      {
        id: d.id, title: d.title, document_type: d.document_type&.name,
        number: d.number, issuer: d.issuer,
        issued_at: d.issued_at, expires_at: d.expires_at,
        state: d.state, confidentiality: d.confidentiality,
        created_at: d.created_at&.iso8601,
        extracted_data: d.extracted_data
      }
    end
  end

  def leaves_data
    return [] unless @employee
    @employee.leave_requests.map do |lr|
      {
        id: lr.id,
        leave_type: lr.leave_type&.name,
        started_on: lr.started_on, ended_on: lr.ended_on,
        days: lr.days, state: lr.state, reason: lr.reason,
        created_at: lr.created_at&.iso8601,
        custom_fields: (lr.respond_to?(:custom_fields) ? lr.custom_fields : nil)
      }
    end
  end

  def kpi_data
    return [] unless @employee
    @employee.kpi_assignments.includes(:kpi_metric, :kpi_evaluations).map do |a|
      {
        metric: a.kpi_metric&.name,
        period_start: a.period_start, period_end: a.period_end,
        target: a.target, weight: a.weight,
        evaluations: a.kpi_evaluations.map { |e| { score: e.score, actual_value: e.actual_value, evaluated_at: e.evaluated_at, notes: e.notes } }
      }
    end
  end

  def interviews_data
    InterviewRound.joins(:job_applicant).where(job_applicants: { email: @user.email }).map do |r|
      {
        kind: r.kind, scheduled_at: r.scheduled_at,
        score: r.overall_score, recommendation: r.recommendation,
        notes: r.notes
      }
    end
  rescue StandardError
    []
  end

  def notifications_data
    @user.notifications.map do |n|
      { type: n.type, params: n.params, created_at: n.created_at&.iso8601, read_at: n.read_at&.iso8601 }
    end
  end

  def ai_runs_data
    AiRun.where(user_id: @user.id).map do |r|
      { kind: r.kind, model: r.model, success: r.success,
        tokens: r.total_tokens, cost_usd: r.cost_usd,
        created_at: r.created_at&.iso8601 }
    end
  end

  def audit_log_data
    PaperTrail::Version.where(whodunnit: @user.id.to_s).limit(500).map do |v|
      { item_type: v.item_type, item_id: v.item_id, event: v.event, created_at: v.created_at&.iso8601 }
    end
  rescue StandardError
    []
  end
end
