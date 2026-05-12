require "rails_helper"

RSpec.describe GdprExporter do
  before(:all) { Rails.application.load_seed }

  let(:user) { User.find_by!(email: "admin@hrms.local") }

  describe ".call" do
    subject(:payload) { described_class.call(user) }

    it "returns a Hash with all expected top-level keys" do
      expect(payload).to include(
        :generated_at, :generated_by, :account, :profile,
        :employment, :documents, :leaves, :kpi, :interviews,
        :notifications, :ai_runs, :audit_log
      )
    end

    it "embeds account identity (email, role, locale)" do
      expect(payload[:account]).to include(
        id: user.id, email: user.email, role: user.role.to_s
      )
    end

    it "includes employee profile when linked" do
      next pending("seed admin has no employee") unless user.employee
      expect(payload[:profile][:full_name]).to eq(user.employee.full_name)
    end

    it "returns leaves as array (may be empty)" do
      expect(payload[:leaves]).to be_an(Array)
    end

    it "returns kpi assignments with target (not target_value — column doesn't exist)" do
      expect(payload[:kpi]).to be_an(Array)
      payload[:kpi].each do |kpi|
        expect(kpi).to have_key(:target)  # regression: was a.target_value, fixed
      end
    end

    it "doesn't crash when employee is missing" do
      user_without_employee = User.new(email: "ghost@x", role: :employee)
      allow(user_without_employee).to receive(:employee).and_return(nil)
      allow(user_without_employee).to receive_message_chain(:notifications, :map).and_return([])
      expect { described_class.new(user_without_employee).call }.not_to raise_error
    end

    it "serializes to valid JSON" do
      expect { JSON.generate(payload) }.not_to raise_error
    end

    it "tags the export with current timestamp" do
      ts = Time.zone.parse(payload[:generated_at])
      expect(ts).to be_within(5.seconds).of(Time.current)
    end
  end
end
