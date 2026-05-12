class Api::V1::PositionsController < ActionController::API
  before_action :set_company

  def index
    scope = Position.where(company: @company).order(:name)
    scope = scope.where(active: true) if Position.column_names.include?("active")
    rows = scope.map do |p|
      { "id" => p.id, "code" => p.code, "name" => p.name,
        "department" => p.respond_to?(:department) ? p.department&.name : nil }
    end
    render json: { "data" => rows }
  end

  private

  def set_company
    @company = Current.company || Company.kept.first
    head(:service_unavailable) and return unless @company
  end
end
