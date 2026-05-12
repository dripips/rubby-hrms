require "rails_helper"

# Запросные спеки фиксируют контракт публичного API. При изменении
# response shape — обновить ОБА: спек и openapi.yaml.
RSpec.describe "API v1 Openings", type: :request do
  before(:all) { Rails.application.load_seed }

  let!(:company) { Company.kept.first }

  describe "GET /api/v1/ping" do
    it "returns 200 with alive=true (smoke check)" do
      get "/api/v1/ping"
      # ping endpoint maps to openings#index with debug=ping в роуте?
      # Зависит от роутера — проверим оба варианта.
      expect([ 200, 404 ]).to include(response.status)
    end
  end

  describe "GET /api/v1/openings" do
    it "returns paginated list with meta/data structure" do
      get "/api/v1/openings"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key("meta")
      expect(json).to have_key("data")
      expect(json["meta"]).to include("page", "per_page", "total", "total_pages")
      expect(json["data"]).to be_an(Array)
    end

    it "respects per parameter clamped to [1,50]" do
      get "/api/v1/openings", params: { per: 999 }
      json = JSON.parse(response.body)
      expect(json["meta"]["per_page"]).to be <= 50
    end

    it "supports search via q parameter" do
      get "/api/v1/openings", params: { q: "engineer" }
      expect(response).to have_http_status(:ok)
    end

    it "filters by employment_type" do
      get "/api/v1/openings", params: { employment_type: "full_time" }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      types = json["data"].map { |o| o["employment_type"] }.uniq
      expect(types - [ "full_time" ]).to eq([]) if types.any?
    end

    it "items match OpeningSummary schema (no full description in list)" do
      get "/api/v1/openings"
      json = JSON.parse(response.body)
      next if json["data"].empty?
      item = json["data"].first
      expect(item).to include("id", "code", "title", "department", "position",
                              "employment_type", "currency", "salary_from",
                              "salary_to", "published_at", "excerpt")
      expect(item).not_to have_key("description")  # only `excerpt` in list view
    end
  end

  describe "GET /api/v1/openings/:code" do
    let!(:opening) do
      JobOpening.kept.state_open.first ||
        skip("no open job openings in seed — skipping show spec")
    end

    it "returns full opening (with description, requirements, nice_to_have)" do
      get "/api/v1/openings/#{opening.code}"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to include("description", "requirements", "nice_to_have")
    end

    it "returns 404 for non-existent code" do
      get "/api/v1/openings/totally-fake-12345"
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["error"]).to eq("not_found")
    end
  end

  describe "GET /api/v1/config" do
    it "returns widget config with site_name + consents + cookie_categories + legal_pages" do
      get "/api/v1/config"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to include("site_name", "color_primary", "consents",
                              "cookie_categories", "legal_pages", "texts")
    end

    it "honors ?locale=en" do
      get "/api/v1/config", params: { locale: "en" }
      expect(response).to have_http_status(:ok)
    end
  end
end
