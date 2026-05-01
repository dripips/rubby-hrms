# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_01_161501) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_runs", force: :cascade do |t|
    t.decimal "cost_usd", precision: 10, scale: 6, default: "0.0"
    t.datetime "created_at", null: false
    t.bigint "dictionary_id"
    t.bigint "document_id"
    t.bigint "employee_id"
    t.text "error"
    t.integer "input_tokens", default: 0
    t.bigint "interview_round_id"
    t.bigint "job_applicant_id"
    t.bigint "job_opening_id"
    t.string "kind", null: false
    t.string "model", null: false
    t.bigint "offboarding_process_id"
    t.bigint "onboarding_process_id"
    t.integer "output_tokens", default: 0
    t.jsonb "payload", default: {}, null: false
    t.boolean "success", default: false, null: false
    t.integer "total_tokens", default: 0
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["dictionary_id"], name: "index_ai_runs_on_dictionary_id"
    t.index ["document_id"], name: "index_ai_runs_on_document_id"
    t.index ["employee_id"], name: "index_ai_runs_on_employee_id"
    t.index ["interview_round_id", "created_at"], name: "index_ai_runs_on_interview_round_id_and_created_at"
    t.index ["interview_round_id"], name: "index_ai_runs_on_interview_round_id"
    t.index ["job_applicant_id", "created_at"], name: "index_ai_runs_on_job_applicant_id_and_created_at"
    t.index ["job_applicant_id"], name: "index_ai_runs_on_job_applicant_id"
    t.index ["job_opening_id"], name: "index_ai_runs_on_job_opening_id"
    t.index ["kind"], name: "index_ai_runs_on_kind"
    t.index ["offboarding_process_id"], name: "index_ai_runs_on_offboarding_process_id"
    t.index ["onboarding_process_id"], name: "index_ai_runs_on_onboarding_process_id"
    t.index ["user_id"], name: "index_ai_runs_on_user_id"
  end

  create_table "app_settings", force: :cascade do |t|
    t.string "category", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.text "secret"
    t.datetime "updated_at", null: false
    t.index ["company_id", "category"], name: "index_app_settings_on_company_id_and_category", unique: true
    t.index ["company_id"], name: "index_app_settings_on_company_id"
  end

  create_table "applicant_notes", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.bigint "job_applicant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_applicant_notes_on_author_id"
    t.index ["discarded_at"], name: "index_applicant_notes_on_discarded_at"
    t.index ["job_applicant_id"], name: "index_applicant_notes_on_job_applicant_id"
  end

  create_table "application_stage_changes", force: :cascade do |t|
    t.datetime "changed_at", null: false
    t.text "comment"
    t.datetime "created_at", null: false
    t.string "from_stage"
    t.bigint "job_applicant_id", null: false
    t.string "to_stage", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["changed_at"], name: "index_application_stage_changes_on_changed_at"
    t.index ["job_applicant_id"], name: "index_application_stage_changes_on_job_applicant_id"
    t.index ["user_id"], name: "index_application_stage_changes_on_user_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "address"
    t.string "code", limit: 32
    t.string "country", limit: 2, default: "RU"
    t.datetime "created_at", null: false
    t.string "default_currency", limit: 3, default: "RUB"
    t.string "default_locale", limit: 5, default: "ru"
    t.string "default_time_zone", default: "Moscow"
    t.datetime "discarded_at"
    t.string "email"
    t.string "inn", limit: 12
    t.string "kpp", limit: 9
    t.string "legal_name"
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_companies_on_code", unique: true, where: "(code IS NOT NULL)"
    t.index ["discarded_at"], name: "index_companies_on_discarded_at"
    t.index ["inn"], name: "index_companies_on_inn", unique: true, where: "(inn IS NOT NULL)"
  end

  create_table "contracts", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "RUB"
    t.datetime "discarded_at"
    t.bigint "employee_id", null: false
    t.date "ended_at"
    t.integer "kind", default: 0, null: false
    t.string "number", limit: 64
    t.decimal "salary", precision: 12, scale: 2
    t.date "signed_at"
    t.date "started_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "working_rate", precision: 4, scale: 2, default: "1.0"
    t.index ["employee_id", "active"], name: "index_contracts_on_employee_id_and_active"
    t.index ["employee_id"], name: "index_contracts_on_employee_id"
    t.index ["started_at"], name: "index_contracts_on_started_at"
  end

  create_table "department_hierarchies", id: false, force: :cascade do |t|
    t.integer "ancestor_id", null: false
    t.integer "descendant_id", null: false
    t.integer "generations", null: false
    t.index ["ancestor_id", "descendant_id", "generations"], name: "department_anc_desc_idx", unique: true
    t.index ["descendant_id"], name: "department_desc_idx"
  end

  create_table "departments", force: :cascade do |t|
    t.string "code", limit: 32
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "custom_fields", default: {}
    t.datetime "discarded_at"
    t.bigint "head_employee_id"
    t.string "name", null: false
    t.bigint "parent_id"
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "code"], name: "index_departments_on_company_id_and_code", unique: true, where: "(code IS NOT NULL)"
    t.index ["company_id"], name: "index_departments_on_company_id"
    t.index ["discarded_at"], name: "index_departments_on_discarded_at"
    t.index ["head_employee_id"], name: "index_departments_on_head_employee_id"
    t.index ["parent_id"], name: "index_departments_on_parent_id"
  end

  create_table "dictionaries", force: :cascade do |t|
    t.string "code", limit: 64, null: false
    t.bigint "company_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discarded_at"
    t.string "kind", default: "lookup", null: false
    t.string "name", null: false
    t.boolean "system", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "code"], name: "index_dictionaries_on_company_id_and_code", unique: true
    t.index ["company_id", "kind"], name: "index_dictionaries_on_company_id_and_kind"
    t.index ["company_id"], name: "index_dictionaries_on_company_id"
  end

  create_table "dictionary_entries", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "dictionary_id", null: false
    t.datetime "discarded_at"
    t.string "key", limit: 64, null: false
    t.jsonb "meta", default: {}
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "value", null: false
    t.index ["dictionary_id", "key"], name: "index_dictionary_entries_on_dictionary_id_and_key", unique: true
    t.index ["dictionary_id"], name: "index_dictionary_entries_on_dictionary_id"
    t.index ["meta"], name: "index_dictionary_entries_on_meta", using: :gin
  end

  create_table "document_types", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", limit: 32, null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.integer "default_validity_months"
    t.text "description"
    t.datetime "discarded_at"
    t.string "extractor_kind"
    t.string "icon"
    t.string "name", null: false
    t.boolean "required", default: false, null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "code"], name: "index_document_types_on_company_id_and_code", unique: true
    t.index ["company_id"], name: "index_document_types_on_company_id"
    t.index ["extractor_kind"], name: "index_document_types_on_extractor_kind"
  end

  create_table "documents", force: :cascade do |t|
    t.string "confidentiality", default: "internal", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.datetime "discarded_at"
    t.bigint "document_type_id", null: false
    t.bigint "documentable_id", null: false
    t.string "documentable_type", null: false
    t.date "expires_at"
    t.datetime "extracted_at"
    t.jsonb "extracted_data", default: {}
    t.string "extraction_method"
    t.date "issued_at"
    t.string "issuer"
    t.text "notes"
    t.string "number"
    t.string "state", default: "active", null: false
    t.text "summary"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["confidentiality"], name: "index_documents_on_confidentiality"
    t.index ["created_by_id"], name: "index_documents_on_created_by_id"
    t.index ["discarded_at"], name: "index_documents_on_discarded_at"
    t.index ["document_type_id"], name: "index_documents_on_document_type_id"
    t.index ["documentable_type", "documentable_id"], name: "index_documents_on_documentable"
    t.index ["expires_at"], name: "index_documents_on_expires_at"
    t.index ["state"], name: "index_documents_on_state"
  end

  create_table "employee_children", force: :cascade do |t|
    t.date "birth_date", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.bigint "employee_id", null: false
    t.string "first_name", null: false
    t.bigint "gender_ref_id"
    t.string "last_name"
    t.text "notes"
    t.datetime "updated_at", null: false
    t.index ["birth_date"], name: "index_employee_children_on_birth_date"
    t.index ["employee_id"], name: "index_employee_children_on_employee_id"
    t.index ["gender_ref_id"], name: "index_employee_children_on_gender_ref_id"
  end

  create_table "employee_notes", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.bigint "employee_id", null: false
    t.boolean "hr_only", default: false, null: false
    t.boolean "pinned", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_employee_notes_on_author_id"
    t.index ["employee_id", "pinned", "created_at"], name: "idx_employee_notes_listing"
    t.index ["employee_id"], name: "index_employee_notes_on_employee_id"
  end

  create_table "employees", force: :cascade do |t|
    t.string "address"
    t.date "birth_date"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "custom_fields", default: {}
    t.bigint "department_id"
    t.text "dietary_restrictions"
    t.datetime "discarded_at"
    t.string "education_institution"
    t.string "education_level", limit: 64
    t.string "emergency_contact_name"
    t.string "emergency_contact_phone"
    t.string "emergency_contact_relation", limit: 64
    t.integer "employment_type", default: 0, null: false
    t.string "first_name", null: false
    t.integer "gender", default: 0, null: false
    t.bigint "gender_ref_id"
    t.bigint "grade_id"
    t.boolean "has_disability", default: false, null: false
    t.date "hired_at", null: false
    t.text "hobbies"
    t.string "insurance_id", limit: 32
    t.string "last_name", null: false
    t.bigint "manager_id"
    t.string "marital_status", limit: 32
    t.string "middle_name"
    t.string "native_city"
    t.date "passport_issued_at"
    t.string "passport_issued_by"
    t.string "passport_number", limit: 32
    t.string "personal_email"
    t.string "personnel_number", limit: 32, null: false
    t.string "phone"
    t.bigint "position_id"
    t.string "preferred_language", limit: 8
    t.string "shirt_size", limit: 16
    t.text "special_needs"
    t.integer "state", default: 1, null: false
    t.string "tax_id", limit: 32
    t.date "terminated_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["company_id", "personnel_number"], name: "index_employees_on_company_id_and_personnel_number", unique: true
    t.index ["company_id"], name: "index_employees_on_company_id"
    t.index ["department_id"], name: "index_employees_on_department_id"
    t.index ["discarded_at"], name: "index_employees_on_discarded_at"
    t.index ["gender_ref_id"], name: "index_employees_on_gender_ref_id"
    t.index ["grade_id"], name: "index_employees_on_grade_id"
    t.index ["last_name", "first_name"], name: "index_employees_on_last_name_and_first_name"
    t.index ["manager_id"], name: "index_employees_on_manager_id"
    t.index ["position_id"], name: "index_employees_on_position_id"
    t.index ["state"], name: "index_employees_on_state"
    t.index ["user_id"], name: "index_employees_on_user_id", unique: true
  end

  create_table "genders", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "avatar_seed", limit: 32
    t.string "code", limit: 32, null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "name", null: false
    t.string "pronouns", limit: 64
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "code"], name: "index_genders_on_company_id_and_code", unique: true
    t.index ["company_id"], name: "index_genders_on_company_id"
  end

  create_table "grades", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "RUB"
    t.datetime "discarded_at"
    t.integer "level", default: 0, null: false
    t.decimal "max_salary", precision: 12, scale: 2
    t.decimal "min_salary", precision: 12, scale: 2
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_grades_on_active"
    t.index ["company_id", "level"], name: "index_grades_on_company_id_and_level", unique: true
    t.index ["company_id"], name: "index_grades_on_company_id"
  end

  create_table "grid_preferences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.string "key", limit: 64, null: false
    t.string "kind", limit: 32, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["data"], name: "index_grid_preferences_on_data", using: :gin
    t.index ["user_id", "key", "kind"], name: "grid_prefs_uniq", unique: true
    t.index ["user_id"], name: "index_grid_preferences_on_user_id"
  end

  create_table "holidays", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.boolean "is_workday", default: false, null: false
    t.string "name", null: false
    t.string "region", limit: 8
    t.datetime "updated_at", null: false
    t.index ["company_id", "date", "region"], name: "holidays_unique_idx", unique: true
    t.index ["company_id"], name: "index_holidays_on_company_id"
  end

  create_table "interview_rounds", force: :cascade do |t|
    t.jsonb "competency_scores", default: {}, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.text "decision_comment"
    t.date "digest_notified_on"
    t.datetime "discarded_at"
    t.integer "duration_minutes", default: 60
    t.bigint "interviewer_id"
    t.bigint "job_applicant_id", null: false
    t.string "kind", default: "hr", null: false
    t.string "location"
    t.string "meeting_url"
    t.text "notes"
    t.integer "overall_score"
    t.string "recommendation"
    t.datetime "scheduled_at", null: false
    t.datetime "soon_notified_at"
    t.datetime "started_at"
    t.string "state", default: "scheduled", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_interview_rounds_on_created_by_id"
    t.index ["discarded_at"], name: "index_interview_rounds_on_discarded_at"
    t.index ["interviewer_id"], name: "index_interview_rounds_on_interviewer_id"
    t.index ["job_applicant_id"], name: "index_interview_rounds_on_job_applicant_id"
    t.index ["scheduled_at"], name: "index_interview_rounds_on_scheduled_at"
    t.index ["state"], name: "index_interview_rounds_on_state"
  end

  create_table "job_applicants", force: :cascade do |t|
    t.datetime "applied_at", null: false
    t.bigint "company_id", null: false
    t.jsonb "consents", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "RUB"
    t.string "current_company"
    t.string "current_position"
    t.jsonb "custom_fields", default: {}
    t.datetime "discarded_at"
    t.string "email"
    t.decimal "expected_salary", precision: 12, scale: 2
    t.string "first_name", null: false
    t.string "github_url"
    t.bigint "job_opening_id"
    t.string "last_name", null: false
    t.string "linkedin_url"
    t.string "location"
    t.integer "overall_score"
    t.bigint "owner_id"
    t.string "phone"
    t.string "portfolio_url"
    t.string "source", default: "manual", null: false
    t.jsonb "source_meta", default: {}
    t.string "stage", default: "applied", null: false
    t.datetime "stage_changed_at"
    t.text "summary"
    t.string "telegram"
    t.datetime "updated_at", null: false
    t.integer "years_of_experience"
    t.index ["applied_at"], name: "index_job_applicants_on_applied_at"
    t.index ["company_id"], name: "index_job_applicants_on_company_id"
    t.index ["consents"], name: "index_job_applicants_on_consents", using: :gin
    t.index ["discarded_at"], name: "index_job_applicants_on_discarded_at"
    t.index ["email"], name: "index_job_applicants_on_email"
    t.index ["job_opening_id"], name: "index_job_applicants_on_job_opening_id"
    t.index ["last_name", "first_name"], name: "index_job_applicants_on_last_name_and_first_name"
    t.index ["owner_id"], name: "index_job_applicants_on_owner_id"
    t.index ["source"], name: "index_job_applicants_on_source"
    t.index ["source_meta"], name: "index_job_applicants_on_source_meta", using: :gin
    t.index ["stage"], name: "index_job_applicants_on_stage"
  end

  create_table "job_openings", force: :cascade do |t|
    t.date "closes_at"
    t.string "code", limit: 32
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "RUB"
    t.bigint "department_id"
    t.text "description"
    t.datetime "discarded_at"
    t.string "employment_type", default: "full_time"
    t.bigint "grade_id"
    t.text "nice_to_have"
    t.integer "openings_count", default: 1, null: false
    t.bigint "owner_id"
    t.bigint "position_id"
    t.date "published_at"
    t.text "requirements"
    t.decimal "salary_from", precision: 12, scale: 2
    t.decimal "salary_to", precision: 12, scale: 2
    t.integer "state", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "code"], name: "index_job_openings_on_company_id_and_code", unique: true, where: "(code IS NOT NULL)"
    t.index ["company_id"], name: "index_job_openings_on_company_id"
    t.index ["department_id"], name: "index_job_openings_on_department_id"
    t.index ["discarded_at"], name: "index_job_openings_on_discarded_at"
    t.index ["grade_id"], name: "index_job_openings_on_grade_id"
    t.index ["owner_id"], name: "index_job_openings_on_owner_id"
    t.index ["position_id"], name: "index_job_openings_on_position_id"
    t.index ["state"], name: "index_job_openings_on_state"
  end

  create_table "kpi_assignments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "employee_id", null: false
    t.bigint "kpi_metric_id", null: false
    t.date "period_end", null: false
    t.date "period_start", null: false
    t.decimal "target", precision: 12, scale: 2
    t.datetime "updated_at", null: false
    t.decimal "weight", precision: 5, scale: 2, default: "1.0"
    t.index ["employee_id", "kpi_metric_id", "period_start"], name: "kpi_assignment_uniq", unique: true
    t.index ["employee_id"], name: "index_kpi_assignments_on_employee_id"
    t.index ["kpi_metric_id"], name: "index_kpi_assignments_on_kpi_metric_id"
    t.index ["period_start"], name: "index_kpi_assignments_on_period_start"
  end

  create_table "kpi_evaluations", force: :cascade do |t|
    t.decimal "actual_value", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.datetime "evaluated_at", null: false
    t.bigint "evaluator_id", null: false
    t.bigint "kpi_assignment_id", null: false
    t.text "notes"
    t.decimal "score", precision: 5, scale: 2
    t.datetime "updated_at", null: false
    t.index ["evaluated_at"], name: "index_kpi_evaluations_on_evaluated_at"
    t.index ["evaluator_id"], name: "index_kpi_evaluations_on_evaluator_id"
    t.index ["kpi_assignment_id"], name: "index_kpi_evaluations_on_kpi_assignment_id"
  end

  create_table "kpi_metrics", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", limit: 64, null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "name", null: false
    t.integer "target_direction", default: 0, null: false
    t.string "unit", limit: 16
    t.datetime "updated_at", null: false
    t.decimal "weight_default", precision: 5, scale: 2, default: "1.0"
    t.index ["active"], name: "index_kpi_metrics_on_active"
    t.index ["company_id", "code"], name: "index_kpi_metrics_on_company_id_and_code", unique: true
    t.index ["company_id"], name: "index_kpi_metrics_on_company_id"
  end

  create_table "languages", force: :cascade do |t|
    t.string "code", limit: 8, null: false
    t.datetime "created_at", null: false
    t.integer "direction", default: 0, null: false
    t.datetime "discarded_at"
    t.boolean "enabled", default: true, null: false
    t.string "english_name", null: false
    t.string "flag", limit: 8
    t.boolean "is_default", default: false, null: false
    t.string "native_name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_languages_on_code", unique: true
    t.index ["discarded_at"], name: "index_languages_on_discarded_at"
    t.index ["enabled"], name: "index_languages_on_enabled"
    t.index ["is_default"], name: "index_languages_on_is_default", unique: true, where: "(is_default = true)"
  end

  create_table "leave_approval_rules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.jsonb "approval_chain", default: [], null: false
    t.boolean "auto_approve", default: false, null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.bigint "department_id"
    t.text "description"
    t.datetime "discarded_at"
    t.bigint "leave_type_id"
    t.integer "max_days"
    t.integer "min_days"
    t.bigint "min_grade_id"
    t.string "name", null: false
    t.integer "priority", default: 100, null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "priority"], name: "index_leave_approval_rules_on_company_id_and_priority"
    t.index ["company_id"], name: "index_leave_approval_rules_on_company_id"
    t.index ["department_id"], name: "index_leave_approval_rules_on_department_id"
    t.index ["discarded_at"], name: "index_leave_approval_rules_on_discarded_at"
    t.index ["leave_type_id"], name: "index_leave_approval_rules_on_leave_type_id"
    t.index ["min_grade_id"], name: "index_leave_approval_rules_on_min_grade_id"
  end

  create_table "leave_approvals", force: :cascade do |t|
    t.bigint "approver_id", null: false
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "decided_at"
    t.integer "decision", default: 0, null: false
    t.bigint "leave_request_id", null: false
    t.integer "step", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["approver_id"], name: "index_leave_approvals_on_approver_id"
    t.index ["leave_request_id", "step"], name: "leave_approval_step_uniq", unique: true
    t.index ["leave_request_id"], name: "index_leave_approvals_on_leave_request_id"
  end

  create_table "leave_balances", force: :cascade do |t|
    t.decimal "accrued_days", precision: 6, scale: 2, default: "0.0"
    t.decimal "carried_over_days", precision: 6, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.bigint "employee_id", null: false
    t.bigint "leave_type_id", null: false
    t.datetime "updated_at", null: false
    t.decimal "used_days", precision: 6, scale: 2, default: "0.0"
    t.integer "year", null: false
    t.index ["employee_id", "leave_type_id", "year"], name: "leave_balances_uniq_idx", unique: true
    t.index ["employee_id"], name: "index_leave_balances_on_employee_id"
    t.index ["leave_type_id"], name: "index_leave_balances_on_leave_type_id"
  end

  create_table "leave_requests", force: :cascade do |t|
    t.datetime "applied_at"
    t.datetime "created_at", null: false
    t.jsonb "custom_fields", default: {}
    t.decimal "days", precision: 6, scale: 2, null: false
    t.datetime "discarded_at"
    t.bigint "employee_id", null: false
    t.date "ended_on", null: false
    t.bigint "leave_type_id", null: false
    t.text "reason"
    t.date "started_on", null: false
    t.string "state", limit: 32, default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_leave_requests_on_discarded_at"
    t.index ["employee_id"], name: "index_leave_requests_on_employee_id"
    t.index ["leave_type_id"], name: "index_leave_requests_on_leave_type_id"
    t.index ["started_on", "ended_on"], name: "index_leave_requests_on_started_on_and_ended_on"
    t.index ["state"], name: "index_leave_requests_on_state"
  end

  create_table "leave_types", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", limit: 32, null: false
    t.string "color", limit: 8, default: "#007AFF"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "custom_fields", default: {}
    t.integer "default_days_per_year", default: 0
    t.datetime "discarded_at"
    t.string "name", null: false
    t.boolean "paid", default: true, null: false
    t.boolean "requires_doc", default: false, null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "code"], name: "index_leave_types_on_company_id_and_code", unique: true
    t.index ["company_id"], name: "index_leave_types_on_company_id"
  end

  create_table "noticed_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "notifications_count"
    t.jsonb "params"
    t.bigint "record_id"
    t.string "record_type"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id"], name: "index_noticed_events_on_record"
  end

  create_table "noticed_notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "read_at", precision: nil
    t.bigint "recipient_id", null: false
    t.string "recipient_type", null: false
    t.datetime "seen_at", precision: nil
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_noticed_notifications_on_event_id"
    t.index ["recipient_type", "recipient_id"], name: "index_noticed_notifications_on_recipient"
  end

  create_table "offboarding_processes", force: :cascade do |t|
    t.text "ai_summary"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.datetime "discarded_at"
    t.bigint "employee_id", null: false
    t.integer "exit_risk_score"
    t.jsonb "knowledge_areas", default: []
    t.date "last_day"
    t.string "reason", default: "voluntary", null: false
    t.string "state", default: "draft", null: false
    t.bigint "template_id"
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_offboarding_processes_on_created_by_id"
    t.index ["discarded_at"], name: "index_offboarding_processes_on_discarded_at"
    t.index ["employee_id"], name: "index_offboarding_processes_on_employee_id"
    t.index ["state"], name: "index_offboarding_processes_on_state"
    t.index ["template_id"], name: "index_offboarding_processes_on_template_id"
  end

  create_table "offboarding_tasks", force: :cascade do |t|
    t.boolean "ai_generated", default: false, null: false
    t.bigint "assignee_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.date "due_on"
    t.string "kind", default: "general", null: false
    t.bigint "offboarding_process_id", null: false
    t.integer "position", default: 0, null: false
    t.string "state", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_offboarding_tasks_on_assignee_id"
    t.index ["due_on"], name: "index_offboarding_tasks_on_due_on"
    t.index ["offboarding_process_id"], name: "idx_off_tasks_process"
    t.index ["state"], name: "index_offboarding_tasks_on_state"
  end

  create_table "onboarding_processes", force: :cascade do |t|
    t.text "ai_summary"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.datetime "discarded_at"
    t.bigint "employee_id", null: false
    t.bigint "mentor_id"
    t.date "started_on"
    t.string "state", default: "draft", null: false
    t.date "target_complete_on"
    t.bigint "template_id"
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_onboarding_processes_on_created_by_id"
    t.index ["discarded_at"], name: "index_onboarding_processes_on_discarded_at"
    t.index ["employee_id"], name: "index_onboarding_processes_on_employee_id"
    t.index ["mentor_id"], name: "index_onboarding_processes_on_mentor_id"
    t.index ["state"], name: "index_onboarding_processes_on_state"
    t.index ["template_id"], name: "index_onboarding_processes_on_template_id"
  end

  create_table "onboarding_tasks", force: :cascade do |t|
    t.boolean "ai_generated", default: false, null: false
    t.bigint "assignee_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.date "due_on"
    t.string "kind", default: "general", null: false
    t.bigint "onboarding_process_id", null: false
    t.integer "position", default: 0, null: false
    t.string "state", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_onboarding_tasks_on_assignee_id"
    t.index ["due_on"], name: "index_onboarding_tasks_on_due_on"
    t.index ["onboarding_process_id"], name: "idx_ob_tasks_process"
    t.index ["state"], name: "index_onboarding_tasks_on_state"
  end

  create_table "positions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "category", limit: 64
    t.string "code", limit: 32
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "custom_fields", default: {}
    t.datetime "discarded_at"
    t.string "name", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_positions_on_active"
    t.index ["company_id", "code"], name: "index_positions_on_company_id_and_code", unique: true, where: "(code IS NOT NULL)"
    t.index ["company_id"], name: "index_positions_on_company_id"
    t.index ["discarded_at"], name: "index_positions_on_discarded_at"
  end

  create_table "process_templates", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.boolean "default_template", default: false, null: false
    t.text "description"
    t.datetime "discarded_at"
    t.jsonb "items", default: [], null: false
    t.string "kind", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "kind", "active"], name: "index_process_templates_on_company_id_and_kind_and_active"
    t.index ["company_id"], name: "index_process_templates_on_company_id"
    t.index ["discarded_at"], name: "index_process_templates_on_discarded_at"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "test_assignments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.datetime "deadline"
    t.text "description"
    t.datetime "discarded_at"
    t.bigint "job_applicant_id", null: false
    t.text "requirements"
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.text "reviewer_notes"
    t.integer "score"
    t.string "state", default: "sent", null: false
    t.text "submission_text"
    t.datetime "submitted_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_test_assignments_on_created_by_id"
    t.index ["deadline"], name: "index_test_assignments_on_deadline"
    t.index ["discarded_at"], name: "index_test_assignments_on_discarded_at"
    t.index ["job_applicant_id"], name: "index_test_assignments_on_job_applicant_id"
    t.index ["reviewed_by_id"], name: "index_test_assignments_on_reviewed_by_id"
    t.index ["state"], name: "index_test_assignments_on_state"
  end

  create_table "time_entries", force: :cascade do |t|
    t.text "comment"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.bigint "employee_id", null: false
    t.decimal "hours", precision: 5, scale: 2, default: "0.0", null: false
    t.integer "kind", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "date"], name: "index_time_entries_on_employee_id_and_date", unique: true
    t.index ["employee_id"], name: "index_time_entries_on_employee_id"
  end

  create_table "translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "interpolations"
    t.boolean "is_proc", default: false, null: false
    t.string "key", null: false
    t.string "locale", limit: 8, null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["key"], name: "index_translations_on_key"
    t.index ["locale", "key"], name: "index_translations_on_locale_and_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.jsonb "dashboard_preferences", default: {}
    t.datetime "discarded_at"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "last_seen_at"
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.string "locale", limit: 5, default: "ru", null: false
    t.jsonb "notification_preferences", default: {}, null: false
    t.text "otp_backup_codes"
    t.datetime "otp_enabled_at"
    t.datetime "otp_last_used_at"
    t.boolean "otp_required_for_login", default: false, null: false
    t.string "otp_secret"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.integer "sign_in_count", default: 0, null: false
    t.string "time_zone", default: "Moscow", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_users_on_discarded_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.jsonb "metadata", default: {}, null: false
    t.text "object"
    t.text "object_changes"
    t.datetime "reverted_at"
    t.string "reverted_by"
    t.string "whodunnit"
    t.index ["created_at"], name: "index_versions_on_created_at"
    t.index ["event"], name: "index_versions_on_event"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["whodunnit"], name: "index_versions_on_whodunnit"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_runs", "dictionaries"
  add_foreign_key "ai_runs", "documents"
  add_foreign_key "ai_runs", "employees"
  add_foreign_key "ai_runs", "interview_rounds"
  add_foreign_key "ai_runs", "job_applicants"
  add_foreign_key "ai_runs", "job_openings"
  add_foreign_key "ai_runs", "offboarding_processes"
  add_foreign_key "ai_runs", "onboarding_processes"
  add_foreign_key "ai_runs", "users"
  add_foreign_key "app_settings", "companies"
  add_foreign_key "applicant_notes", "job_applicants"
  add_foreign_key "applicant_notes", "users", column: "author_id"
  add_foreign_key "application_stage_changes", "job_applicants"
  add_foreign_key "application_stage_changes", "users"
  add_foreign_key "contracts", "employees"
  add_foreign_key "departments", "companies"
  add_foreign_key "departments", "departments", column: "parent_id"
  add_foreign_key "departments", "employees", column: "head_employee_id"
  add_foreign_key "dictionaries", "companies"
  add_foreign_key "dictionary_entries", "dictionaries"
  add_foreign_key "document_types", "companies"
  add_foreign_key "documents", "document_types"
  add_foreign_key "documents", "users", column: "created_by_id"
  add_foreign_key "employee_children", "employees"
  add_foreign_key "employee_children", "genders", column: "gender_ref_id"
  add_foreign_key "employee_notes", "employees"
  add_foreign_key "employee_notes", "users", column: "author_id"
  add_foreign_key "employees", "companies"
  add_foreign_key "employees", "departments"
  add_foreign_key "employees", "employees", column: "manager_id"
  add_foreign_key "employees", "genders", column: "gender_ref_id"
  add_foreign_key "employees", "grades"
  add_foreign_key "employees", "positions"
  add_foreign_key "employees", "users"
  add_foreign_key "genders", "companies"
  add_foreign_key "grades", "companies"
  add_foreign_key "grid_preferences", "users"
  add_foreign_key "holidays", "companies"
  add_foreign_key "interview_rounds", "job_applicants"
  add_foreign_key "interview_rounds", "users", column: "created_by_id"
  add_foreign_key "interview_rounds", "users", column: "interviewer_id"
  add_foreign_key "job_applicants", "companies"
  add_foreign_key "job_applicants", "job_openings"
  add_foreign_key "job_applicants", "users", column: "owner_id"
  add_foreign_key "job_openings", "companies"
  add_foreign_key "job_openings", "departments"
  add_foreign_key "job_openings", "grades"
  add_foreign_key "job_openings", "positions"
  add_foreign_key "job_openings", "users", column: "owner_id"
  add_foreign_key "kpi_assignments", "employees"
  add_foreign_key "kpi_assignments", "kpi_metrics"
  add_foreign_key "kpi_evaluations", "kpi_assignments"
  add_foreign_key "kpi_evaluations", "users", column: "evaluator_id"
  add_foreign_key "kpi_metrics", "companies"
  add_foreign_key "leave_approval_rules", "companies"
  add_foreign_key "leave_approval_rules", "departments"
  add_foreign_key "leave_approval_rules", "grades", column: "min_grade_id"
  add_foreign_key "leave_approval_rules", "leave_types"
  add_foreign_key "leave_approvals", "leave_requests"
  add_foreign_key "leave_approvals", "users", column: "approver_id"
  add_foreign_key "leave_balances", "employees"
  add_foreign_key "leave_balances", "leave_types"
  add_foreign_key "leave_requests", "employees"
  add_foreign_key "leave_requests", "leave_types"
  add_foreign_key "leave_types", "companies"
  add_foreign_key "offboarding_processes", "employees"
  add_foreign_key "offboarding_processes", "process_templates", column: "template_id"
  add_foreign_key "offboarding_processes", "users", column: "created_by_id"
  add_foreign_key "offboarding_tasks", "offboarding_processes"
  add_foreign_key "offboarding_tasks", "users", column: "assignee_id"
  add_foreign_key "onboarding_processes", "employees"
  add_foreign_key "onboarding_processes", "employees", column: "mentor_id"
  add_foreign_key "onboarding_processes", "process_templates", column: "template_id"
  add_foreign_key "onboarding_processes", "users", column: "created_by_id"
  add_foreign_key "onboarding_tasks", "onboarding_processes"
  add_foreign_key "onboarding_tasks", "users", column: "assignee_id"
  add_foreign_key "positions", "companies"
  add_foreign_key "process_templates", "companies"
  add_foreign_key "test_assignments", "job_applicants"
  add_foreign_key "test_assignments", "users", column: "created_by_id"
  add_foreign_key "test_assignments", "users", column: "reviewed_by_id"
  add_foreign_key "time_entries", "employees"
end
