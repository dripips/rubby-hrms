class EmployeeChildrenController < ApplicationController
  before_action :set_employee

  def create
    child = @employee.children.new(child_params)
    if child.save
      redirect_to employee_path(@employee, anchor: "family"), notice: t("employee_children.created")
    else
      redirect_to employee_path(@employee), alert: child.errors.full_messages.to_sentence
    end
  end

  def update
    child = @employee.children.find(params[:id])
    if child.update(child_params)
      redirect_to employee_path(@employee, anchor: "family"), notice: t("employee_children.updated")
    else
      redirect_to employee_path(@employee), alert: child.errors.full_messages.to_sentence
    end
  end

  def destroy
    child = @employee.children.find(params[:id])
    child.discard
    redirect_to employee_path(@employee, anchor: "family"), notice: t("employee_children.deleted")
  end

  private

  def set_employee
    @employee = Employee.kept.find(params[:employee_id])
  end

  def child_params
    params.require(:employee_child).permit(:first_name, :last_name, :birth_date, :gender_ref_id, :notes)
  end
end
