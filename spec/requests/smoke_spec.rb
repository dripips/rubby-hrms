require "rails_helper"

# Smoke-test: загружаем полный seed, логинимся как admin, GET'аем все
# основные страницы. Ловит NoMethodError / NameError в шаблонах ДО мержа —
# в прошлом уже было два таких (a.target_value на KpiAssignment, @employee.gender_ref).
#
# Используем :all-scope чтобы seed грузился один раз на 20+ тестов.
RSpec.describe "smoke", type: :request do
  before(:all) do
    # Seed идемпотентный, грузим в test DB. Внутри seeds password = password123
    # для test env (см. db/seeds.rb).
    Rails.application.load_seed
  end

  before do
    admin = User.find_by(email: "admin@hrms.local")
    raise "Seed didn't create admin@hrms.local" unless admin
    post user_session_path, params: { user: { email: admin.email, password: "password123" } }
    raise "Sign-in failed: #{response.status}" unless [ 200, 302, 303 ].include?(response.status)
  end

  # Главные страницы для каждой роли — supersadmin'у должны быть доступны все.
  # Локаль в URL не указываем — Rails routes её опциональна (`(:locale)`).
  PATHS = %w[
    /dashboard
    /dashboard/customize
    /employees
    /departments
    /recruitment/kanban
    /recruitment/analytics
    /recruitment/calendar
    /job_openings
    /job_applicants
    /interview_rounds
    /leave_requests
    /kpi/dashboard
    /kpi/metrics
    /kpi/assignments
    /documents
    /onboarding_processes
    /offboarding_processes
    /audit
    /profile
    /profile/security
    /profile/notifications
    /profile/integrations
    /profile/privacy
    /settings/languages
    /settings/smtp
    /settings/ai
    /settings/notifications
    /settings/communications
    /settings/genders
    /settings/process_templates
    /settings/document_types
    /settings/positions
    /settings/leave_types
    /settings/dictionaries
    /settings/careers
    /settings/users
    /ai_runs
    /careers
  ].freeze

  PATHS.each do |path|
    it "GET #{path} renders without view-error" do
      get path
      expect([ 200, 302, 303 ]).to include(response.status),
        "Got #{response.status} for #{path}. Body excerpt:\n#{response.body.to_s.first(800)}"
    end
  end
end
