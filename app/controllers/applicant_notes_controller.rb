class ApplicantNotesController < ApplicationController
  before_action :set_applicant, only: %i[create]
  before_action :set_note,      only: %i[destroy]

  def create
    authorize ApplicantNote
    @note = @applicant.notes.create!(author: current_user, body: params.require(:applicant_note).permit(:body)[:body])
    redirect_to job_applicant_path(@applicant), notice: t("applicant_notes.added", default: "Заметка добавлена")
  end

  def destroy
    authorize @note
    @note.discard
    redirect_to job_applicant_path(@note.job_applicant_id), notice: t("applicant_notes.deleted", default: "Заметка удалена")
  end

  private

  def set_applicant
    @applicant = JobApplicant.kept.find(params[:job_applicant_id])
  end

  def set_note
    @note = ApplicantNote.kept.find(params[:id])
  end
end
