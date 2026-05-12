require "rails_helper"

RSpec.describe GdprDeleter do
  before(:all) { Rails.application.load_seed }

  # Каждый тест работает в transaction (use_transactional_fixtures=true в
  # rails_helper), так что мутации откатываются — admin@hrms.local восстанавливается.
  let(:user) { User.find_by!(email: "alice@hrms.local") }

  describe ".call" do
    it "anonymizes email to deleted-user-<id>@hrms.local" do
      original_id = user.id
      described_class.call(user)
      user.reload
      expect(user.email).to eq("deleted-user-#{original_id}@hrms.local")
    end

    it "soft-deletes user (sets discarded_at)" do
      described_class.call(user)
      expect(user.reload.discarded_at).to be_present
    end

    it "resets encrypted_password (login impossible)" do
      old_password = user.encrypted_password
      described_class.call(user)
      user.reload
      expect(user.encrypted_password).not_to eq(old_password)
      # Login через valid_password? либо вернёт false, либо упадёт на
      # BCrypt::Errors::InvalidHash (мы пишем не-bcrypt random hex) —
      # в обоих случаях юзер не залогинится.
      result = begin
                 user.valid_password?("password123")
               rescue BCrypt::Errors::InvalidHash
                 false
               end
      expect(result).to be false
    end

    it "clears notification + dashboard preferences" do
      user.update_column(:notification_preferences, { "interview_soon" => { "email" => true } })
      user.update_column(:dashboard_preferences,    { "order" => [ "kpi_tiles" ] })
      described_class.call(user)
      user.reload
      expect(user.notification_preferences).to eq({})
      expect(user.dashboard_preferences).to eq({})
    end

    it "anonymizes employee PII" do
      next pending("user has no employee") unless user.employee
      employee = user.employee
      described_class.call(user)
      employee.reload
      expect(employee.first_name).to eq("Deleted")
      expect(employee.last_name).to eq("User")
      expect(employee.phone).to be_nil
      expect(employee.personal_email).to be_nil
      expect(employee.discarded_at).to be_present
      expect(employee.state).to eq("terminated")
    end

    it "wraps changes in a transaction (atomicity)" do
      expect(ActiveRecord::Base).to receive(:transaction).and_call_original
      described_class.call(user)
    end
  end
end
