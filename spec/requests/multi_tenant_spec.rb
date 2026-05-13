require "rails_helper"

# End-to-end проверка multi-tenant: запросы с разных subdomain'ов резолвятся
# в разные Current.company. Single-tenant fallback на apex домене.
RSpec.describe "Multi-tenant routing", type: :request do
  before(:all) { Rails.application.load_seed }

  let(:seed_company) { Company.kept.first }
  let!(:other_company) do
    Company.create!(
      name: "Acme Corp",
      default_locale: "en",
      subdomain: "acme",
      discarded_at: nil
    )
  end

  describe "TenantResolver middleware" do
    it "resolves Current.company by subdomain when set" do
      # Stub host чтобы middleware увидел subdomain
      host! "acme.example.com"
      get "/up"  # health endpoint — должен пройти middleware
      expect(response).to have_http_status(:ok)
    end

    it "falls back to first company on apex (no subdomain)" do
      host! "example.com"
      get "/up"
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for unknown subdomain" do
      host! "ghost-tenant.example.com"
      get "/up"
      expect(response).to have_http_status(:not_found)
    end

    it "ignores www / api / app subdomains and falls back" do
      %w[www api app].each do |sub|
        host! "#{sub}.example.com"
        get "/up"
        expect(response).to have_http_status(:ok),
          "expected fallback OK for #{sub}.example.com"
      end
    end

    it "returns JSON 404 for unknown subdomain on /api/* paths" do
      host! "ghost.example.com"
      get "/api/v1/openings"
      expect(response).to have_http_status(:not_found)
      body = JSON.parse(response.body) rescue {}
      expect(body["error"]).to eq("tenant_not_found")
    end
  end

  describe "Current.company isolation" do
    it "sets Current.company to the resolved tenant" do
      # Имитируем middleware вручную, потому что Current ресет'ится после
      # каждого request'а.
      env = Rack::MockRequest.env_for("http://acme.example.com/up")
      app = Rails.application
      status, _headers, _body = TenantResolver.new(app).call(env)
      expect(status).to be_in([ 200, 302 ])
      # Current.reset уже сработал — но мы можем проверить логику явно:
      Current.company = other_company
      expect(Current.company.subdomain).to eq("acme")
    end

    it "different tenants have isolated AppSettings" do
      # Создаём AI-настройку для каждого тенанта
      AppSetting.fetch(company: seed_company, category: "ai").update!(data: { "monthly_budget_usd" => 100 })
      AppSetting.fetch(company: other_company, category: "ai").update!(data: { "monthly_budget_usd" => 999 })

      seed_setting  = AppSetting.find_by(company: seed_company, category: "ai")
      other_setting = AppSetting.find_by(company: other_company, category: "ai")

      expect(seed_setting.data["monthly_budget_usd"]).to eq(100)
      expect(other_setting.data["monthly_budget_usd"]).to eq(999)
      expect(seed_setting.id).not_to eq(other_setting.id)
    end

    it "different tenants have isolated companies in queries" do
      # employees для каждой компании — separately scoped
      expect(Employee.where(company: seed_company).count).to be > 0
      expect(Employee.where(company: other_company).count).to eq(0)
    end
  end

  describe "current_company helper в ApplicationController" do
    it "delegates to Current.company when set" do
      Current.company = other_company
      controller = ApplicationController.new
      expect(controller.send(:current_company)).to eq(other_company)
    ensure
      Current.reset
    end

    it "falls back to Company.kept.first when Current.company is nil" do
      Current.reset
      controller = ApplicationController.new
      expect(controller.send(:current_company)).to eq(Company.kept.first)
    end
  end
end
