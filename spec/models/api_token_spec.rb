require "rails_helper"

RSpec.describe ApiToken do
  before(:all) { Rails.application.load_seed }

  let(:user) { User.find_by!(email: "alice@hrms.local") }

  describe ".issue!" do
    it "creates a record + returns raw token in hrms_<prefix>_<raw> format" do
      record, raw = described_class.issue!(user: user, name: "iOS")
      expect(record).to be_persisted
      expect(record.name).to eq("iOS")
      expect(record.token_prefix.length).to eq(8)
      expect(raw).to match(/\Ahrms_[a-z0-9]{8}_[a-f0-9]{64}\z/)
    end

    it "stores ONLY a bcrypt hash, never plaintext" do
      _, raw = described_class.issue!(user: user, name: "test")
      record = described_class.last
      expect(record.token_digest).not_to include(raw.split("_").last)
      expect(record.token_digest.length).to be >= 50  # bcrypt $2a$... ≈ 60 chars
    end

    it "supports optional expires_at" do
      record, _ = described_class.issue!(user: user, name: "short", expires_at: 1.hour.from_now)
      expect(record.expires_at).to be_present
    end
  end

  describe ".authenticate" do
    let!(:auth_setup) { described_class.issue!(user: user, name: "test") }
    let(:record) { auth_setup[0] }
    let(:raw)    { auth_setup[1] }

    it "returns the user for a valid raw token" do
      expect(described_class.authenticate(raw)).to eq(user)
    end

    it "returns nil for nil / blank input" do
      expect(described_class.authenticate(nil)).to be_nil
      expect(described_class.authenticate("")).to be_nil
      expect(described_class.authenticate("   ")).to be_nil
    end

    it "returns nil for malformed token" do
      expect(described_class.authenticate("garbage")).to be_nil
      expect(described_class.authenticate("hrms_xxx_yyy")).to be_nil  # wrong lengths
      expect(described_class.authenticate("wrong_#{record.token_prefix}_#{'a' * 64}")).to be_nil
    end

    it "returns nil if prefix matches but body differs" do
      tampered = "hrms_#{record.token_prefix}_#{'f' * 64}"
      expect(described_class.authenticate(tampered)).to be_nil
    end

    it "returns nil for expired token" do
      record.update_columns(expires_at: 1.hour.ago)
      expect(described_class.authenticate(raw)).to be_nil
    end

    it "returns nil if user is discarded" do
      user.update_column(:discarded_at, Time.current)
      expect(described_class.authenticate(raw)).to be_nil
    end

    it "updates last_used_at on success" do
      record.update_column(:last_used_at, nil)
      described_class.authenticate(raw)
      expect(record.reload.last_used_at).to be_present
    end

    it "rate-limits last_used_at updates to once per 60s" do
      described_class.authenticate(raw)
      ts1 = record.reload.last_used_at
      sleep 0.1
      described_class.authenticate(raw)
      ts2 = record.reload.last_used_at
      expect(ts1).to eq(ts2)
    end
  end

  describe "#masked" do
    it "shows prefix but hides body" do
      record, _ = described_class.issue!(user: user, name: "test")
      expect(record.masked).to eq("hrms_#{record.token_prefix}_••••••••")
    end
  end
end
