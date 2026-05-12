class Api::V1::Me::DocumentsController < Api::V1::BaseController
  def index
    emp = current_user.employee
    return render(json: { "data" => [] }) unless emp

    scope = Document.kept.where(documentable: emp).includes(:document_type).order(created_at: :desc)
    render json: paginated(scope) { |d| serialize(d) }
  end

  private

  def serialize(d)
    {
      "id"            => d.id,
      "title"         => d.title,
      "document_type" => d.document_type&.name,
      "number"        => d.number,
      "issuer"        => d.issuer,
      "issued_at"     => d.issued_at,
      "expires_at"    => d.expires_at,
      "state"         => d.state,
      "created_at"    => d.created_at&.iso8601
    }
  end
end
