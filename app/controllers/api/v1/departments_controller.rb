# /api/v1/departments — публичный список (для dropdown-фильтров в careers-widget).
# Без авторизации, без apply_cors (унаследовать из openings_controller pattern если нужен CORS).
class Api::V1::DepartmentsController < ActionController::API
  before_action :set_company

  def index
    rows = Department.kept.where(company: @company).order(:name).map do |d|
      { "id" => d.id, "code" => d.code, "name" => d.name, "parent_id" => d.parent_id }
    end
    render json: { "data" => rows }
  end

  private

  def set_company
    @company = Current.company || Company.kept.first
    head(:service_unavailable) and return unless @company
  end
end
