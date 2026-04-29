class EmployeeNotesController < ApplicationController
  before_action :set_employee

  def create
    note = @employee.notes.new(note_params.merge(author: current_user))
    if note.save
      redirect_to employee_path(@employee, anchor: "notes"), notice: t("employee_notes.created")
    else
      redirect_to employee_path(@employee), alert: note.errors.full_messages.to_sentence
    end
  end

  def destroy
    note = @employee.notes.find(params[:id])
    raise Pundit::NotAuthorizedError unless note.author_id == current_user.id || current_user.role_superadmin? || current_user.role_hr?
    note.discard
    redirect_to employee_path(@employee, anchor: "notes"), notice: t("employee_notes.deleted")
  end

  private

  def set_employee
    @employee = Employee.kept.find(params[:employee_id])
  end

  def note_params
    params.require(:employee_note).permit(:body, :hr_only, :pinned)
  end
end
