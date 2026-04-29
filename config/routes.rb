locale_regex = begin
  codes = Language.available_codes
  codes = Rails.application.config.i18n.available_locales.map(&:to_s) if codes.blank?
  Regexp.new(codes.uniq.map { |c| Regexp.escape(c) }.join("|"))
rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError,
       ActiveRecord::ConnectionNotEstablished, StandardError
  Regexp.new(Rails.application.config.i18n.available_locales.map { |c| Regexp.escape(c.to_s) }.join("|"))
end

Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions:      "users/sessions",
    registrations: "users/registrations"
  }

  # ── Public careers page (без auth) ───────────────────────────────────────
  scope "(:locale)", locale: locale_regex do
    get  "careers",                  to: "careers#index",      as: :careers
    get  "careers/thank-you",        to: "careers#thank_you",  as: :careers_thank_you
    get  "careers/legal/:slug",      to: "careers#page",       as: :careers_page,    constraints: { slug: /privacy|terms|cookies/ }
    get  "careers/:code",            to: "careers#show",       as: :careers_opening, constraints: { code: /[\w\-]+/ }
    post "careers/:code/apply",      to: "careers#create",     as: :apply_careers_opening, constraints: { code: /[\w\-]+/ }
  end

  # ── Public Careers API v1 (CORS, без auth) ───────────────────────────────
  # Позволяет встраивать список вакансий и форму подачи на любой внешний сайт.
  namespace :api do
    namespace :v1 do
      get "ping",  to: "ping#index"
      resources :openings, only: %i[index show]
      post "openings/:code/apply", to: "openings#apply", as: :apply_opening, constraints: { code: /[\w\-]+/ }
      get  "config", to: "openings#widget_config", as: :widget_config
    end
  end

  scope "(:locale)", locale: locale_regex do
    root "dashboard#show"
    get "dashboard", to: "dashboard#show", as: :dashboard

    resources :employees, only: %i[index show create update destroy] do
      resources :notes,    only: %i[create destroy], controller: "employee_notes"
      resources :children, only: %i[create update destroy], controller: "employee_children"
    end

    get  "grid_preferences/:key",       to: "grid_preferences#show",   as: :grid_preferences
    put  "grid_preferences/:key/:kind", to: "grid_preferences#update", as: :update_grid_preference

    resources :departments, only: %i[index show create update destroy]

    # ── Recruitment ─────────────────────────────────────────────────────────
    resources :job_openings do
      member do
        post :open
        post :close
        post :hold
      end
    end
    resources :job_applicants do
      member { post :move_stage }
      resources :applicant_notes,   only: %i[create destroy], shallow: true
      resources :test_assignments,  only: %i[create], shallow: true
      resources :interview_rounds,  only: %i[create], shallow: true
    end
    resources :test_assignments, only: %i[update destroy] do
      member do
        post :start
        post :submit_work
        post :review
        post :cancel
        post :reopen
        post :notify
      end
    end
    resources :interview_rounds, only: %i[index update destroy] do
      member do
        post :start
        post :complete
        post :cancel
        post :no_show
        post :reopen
      end
    end
    get "recruitment/kanban", to: "kanban#index", as: :recruitment_kanban
    get "recruitment/analytics", to: "recruitment_analytics#index", as: :recruitment_analytics
    get "recruitment/calendar",  to: "recruitment_calendar#index", as: :recruitment_calendar
    get "recruitment/calendar/events", to: "recruitment_calendar#events", as: :recruitment_calendar_events

    resources :notifications, only: %i[index destroy] do
      member     { post :read }
      collection { post :mark_all_read }
    end

    namespace :ai do
      post "applicants/:id/analyze_resume",      to: "applicants#analyze_resume",      as: :analyze_resume_applicant
      post "applicants/:id/recommend",           to: "applicants#recommend",           as: :recommend_applicant
      post "applicants/:id/generate_assignment", to: "applicants#generate_assignment", as: :generate_assignment_applicant
      post "rounds/:id/questions",               to: "rounds#questions",               as: :questions_round
      post "rounds/:id/summarize",               to: "rounds#summarize",               as: :summarize_round
      post "openings/:id/compare",               to: "openings#compare",               as: :compare_opening
      post "runs/:id/materialize_assignment",    to: "runs#materialize_assignment",    as: :materialize_assignment_run

      # HR-side AI tasks
      post "employees/:id/burnout_brief",        to: "leaves#burnout_brief",           as: :burnout_brief_employee
      post "employees/:id/suggest_leave_window", to: "leaves#suggest_leave_window",    as: :suggest_leave_window_employee
      post "employees/:id/kpi_brief",            to: "leaves#kpi_brief",               as: :kpi_brief_employee
      post "employees/:id/meeting_agenda",       to: "leaves#meeting_agenda",          as: :meeting_agenda_employee
      post "employees/:id/compensation_review",  to: "leaves#compensation_review",     as: :compensation_review_employee
      post "employees/:id/exit_risk_brief",      to: "leaves#exit_risk_brief",         as: :exit_risk_brief_employee
      post "leaves/bulk_burnout_brief",          to: "leaves#bulk_burnout_brief",      as: :bulk_burnout_brief_leaves
      post "kpi/team_brief",                     to: "kpi#team_brief",                 as: :team_brief_kpi

      # Recruitment-side: offer letter
      post "applicants/:id/offer_letter",        to: "applicants#offer_letter",        as: :offer_letter_applicant

      # Onboarding agents
      post "onboarding_processes/:id/plan",             to: "onboarding#plan",             as: :plan_onboarding
      post "onboarding_processes/:id/welcome_letter",   to: "onboarding#welcome_letter",   as: :welcome_letter_onboarding
      post "onboarding_processes/:id/mentor_match",     to: "onboarding#mentor_match",     as: :mentor_match_onboarding
      post "onboarding_processes/:id/probation_review", to: "onboarding#probation_review", as: :probation_review_onboarding
      post "onboarding_runs/:id/materialize_tasks",     to: "onboarding#materialize_tasks", as: :materialize_tasks_onboarding_run

      # Offboarding agents
      post "offboarding_processes/:id/knowledge_transfer_plan", to: "offboarding#knowledge_transfer_plan", as: :knowledge_transfer_plan_offboarding
      post "offboarding_processes/:id/exit_interview_brief",    to: "offboarding#exit_interview_brief",    as: :exit_interview_brief_offboarding
      post "offboarding_processes/:id/replacement_brief",       to: "offboarding#replacement_brief",       as: :replacement_brief_offboarding
      post "offboarding_runs/:id/create_opening",               to: "offboarding#create_opening",          as: :create_opening_offboarding_run
    end

    resources :onboarding_processes do
      member do
        post :activate
        post :complete
        post :cancel
      end
    end
    resources :onboarding_tasks, only: %i[update]

    resources :offboarding_processes do
      member do
        post :activate
        post :complete
        post :cancel
      end
    end
    resources :offboarding_tasks, only: %i[update]

    resources :leave_requests, only: %i[index show new create destroy] do
      collection do
        post :quick_create
        get  :employee_panel
      end
      member do
        post :submit
        post :approve
        post :approve_manager
        post :approve_hr
        post :force_approve
        post :start
        post :complete
        post :reject
        post :cancel
      end
    end
    get "leaves", to: redirect { |_, req| "/#{req.params[:locale]}/leave_requests".sub("//", "/") }, as: :leaves

    namespace :kpi do
      root to: "dashboard#show", as: :root
      get "dashboard", to: "dashboard#show", as: :dashboard
      resources :metrics
      resources :assignments
      resources :evaluations, only: %i[index create]
    end
    get "kpi", to: redirect { |_, req| "/#{req.params[:locale]}/kpi/dashboard".sub("//", "/") }, as: :kpi
    get "documents",    to: "stub#show", as: :documents,    defaults: { section: "documents" }
    get "dictionaries", to: "stub#show", as: :dictionaries, defaults: { section: "dictionaries" }
    get  "audit",            to: "audit#index",  as: :audit
    post "audit/:id/revert", to: "audit#revert", as: :revert_audit

    namespace :settings do
      root to: "languages#index"
      resources :languages, only: %i[index new create edit update destroy] do
        post  :set_default, on: :member
        patch :toggle,      on: :member
      end
      resources :translations, only: %i[index update create]
      resource  :smtp, only: %i[show update] do
        post :test
      end
      resource :ai, only: %i[show update] do
        post :test
      end
      resource  :notifications, only: %i[show update]
      resource  :communications, only: %i[show update]
      resource  :careers,        only: %i[show update]
      resource  :leaves,         only: %i[show update], controller: "leaves"
      resources :leave_approval_rules, except: [ :show ]
      resources :genders, except: [ :show ]
      resources :process_templates, except: [ :show ]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
