class Ai::RunsController < ApplicationController
  before_action :set_run

  # Превращает AI-сгенерированное задание (kind: generate_assignment) в реальный
  # TestAssignment, привязанный к кандидату.
  def materialize_assignment
    return redirect_back_or_to root_path, alert: "Wrong kind" unless @run.kind == "generate_assignment"
    return redirect_back_or_to root_path, alert: "Empty payload" if @run.payload.blank?

    authorize TestAssignment, :create?

    data = @run.payload
    deadline_days = data["deadline_days"].to_i
    deadline_days = 7 if deadline_days <= 0

    @assignment = @run.job_applicant.test_assignments.create!(
      title:        data["title"].presence || "AI-generated assignment",
      description:  data["description"].to_s,
      requirements: build_requirements_text(data),
      deadline:     deadline_days.days.from_now.to_date,
      created_by:   current_user
    )

    notice = t("ai.assignment_created", default: "Тестовое задание создано из AI-черновика")
    if params[:send_email] == "1"
      MessageDispatcher.deliver!(
        event:          :test_assignment_sent,
        recipient_type: :candidate,
        payload:        { applicant: @run.job_applicant, assignment: @assignment }
      )
      notice = t("ai.assignment_created_sent",
                 default: "Тестовое задание создано и отправлено кандидату на почту")
    end

    redirect_to job_applicant_path(@run.job_applicant_id, anchor: "assignments"), notice: notice
  rescue StandardError => e
    redirect_back_or_to job_applicant_path(@run.job_applicant_id, anchor: "ai"),
                        alert: e.message.first(200)
  end

  private

  def set_run
    @run = AiRun.find(params[:id])
  end

  def build_requirements_text(data)
    parts = []
    parts << data["requirements"].to_s if data["requirements"].present?
    if data["evaluation_criteria"].present?
      parts << "\n\nКритерии оценки:\n#{data["evaluation_criteria"]}"
    end
    if data["estimated_hours"].present? || data["difficulty"].present?
      meta = []
      meta << "Сложность: #{data["difficulty"]}"        if data["difficulty"].present?
      meta << "Оценочное время: ~#{data["estimated_hours"]} часов" if data["estimated_hours"].present?
      parts << "\n\n#{meta.join(' · ')}" if meta.any?
    end
    parts.join.strip
  end
end
