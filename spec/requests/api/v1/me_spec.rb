require "rails_helper"

RSpec.describe "API v1 /me", type: :request do
  before(:all) { Rails.application.load_seed }

  let(:user) { User.find_by!(email: "alice@hrms.local") }
  let(:auth) { _, raw = ApiToken.issue!(user: user, name: "spec"); raw }
  let(:headers) { { "Authorization" => "Bearer #{auth}" } }

  describe "GET /api/v1/me" do
    it "401 without bearer" do
      get "/api/v1/me"
      expect(response).to have_http_status(:unauthorized)
    end

    it "401 with garbage bearer" do
      get "/api/v1/me", headers: { "Authorization" => "Bearer not-a-token" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "200 with valid bearer + returns user profile" do
      get "/api/v1/me", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to include("id", "email", "role", "locale", "two_factor_enabled", "integrations")
      expect(json["email"]).to eq(user.email)
    end

    it "includes employee block when linked" do
      next pending("alice has no employee") unless user.employee
      get "/api/v1/me", headers: headers
      json = JSON.parse(response.body)
      expect(json["employee"]).to include("full_name", "personnel_number", "department")
    end
  end

  describe "PATCH /api/v1/me" do
    it "updates locale + time_zone" do
      patch "/api/v1/me", params: { locale: "en", time_zone: "Berlin" },
                          headers: headers
      expect(response).to have_http_status(:ok)
      user.reload
      expect(user.locale).to eq("en")
      expect(user.time_zone).to eq("Berlin")
    end
  end

  describe "GET /api/v1/me/kpi" do
    it "200 with assignments array" do
      get "/api/v1/me/kpi", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
    end
  end

  describe "GET /api/v1/me/leave_requests" do
    it "200 with paginated structure" do
      get "/api/v1/me/leave_requests", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to include("meta", "data")
      expect(json["meta"]).to include("page", "per_page", "total", "total_pages")
    end
  end

  describe "GET /api/v1/me/documents" do
    it "200 with paginated structure" do
      get "/api/v1/me/documents", headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api/v1/me/notifications" do
    it "200 with paginated structure" do
      get "/api/v1/me/notifications", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
    end

    it "filters unread when ?filter=unread" do
      get "/api/v1/me/notifications", params: { filter: "unread" }, headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/v1/me/notifications/read_all" do
    it "204" do
      post "/api/v1/me/notifications/read_all", headers: headers
      expect(response).to have_http_status(:no_content)
    end
  end
end

RSpec.describe "API v1 metadata", type: :request do
  before(:all) { Rails.application.load_seed }

  describe "GET /api/v1/departments" do
    it "200 + returns data array (no auth required)" do
      get "/api/v1/departments"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
      next if json["data"].empty?
      expect(json["data"].first).to include("id", "code", "name")
    end
  end

  describe "GET /api/v1/positions" do
    it "200 + returns data array (no auth required)" do
      get "/api/v1/positions"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
    end
  end
end
