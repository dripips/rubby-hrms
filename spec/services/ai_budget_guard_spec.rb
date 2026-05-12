require "rails_helper"

RSpec.describe AiBudgetGuard do
  around do |ex|
    # Test env по умолчанию :null_store — заменяем на MemoryStore чтобы
    # действительно проверить кэширование.
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    ex.run
  ensure
    Rails.cache = original_cache
  end

  before { described_class.invalidate_cache! }

  # Минимальный stub для AppSetting — нужен только метод data.
  let(:setting) { OpenStruct.new(data: { "monthly_budget_usd" => 100.0 }) }

  describe ".over_budget?" do
    it "returns false when budget is 0 / unset (guard disabled)" do
      setting.data["monthly_budget_usd"] = 0
      expect(described_class.over_budget?(setting)).to be false
    end

    it "returns false when spent < budget × multiplier" do
      allow(described_class).to receive(:month_spent).and_return(50.0)
      expect(described_class.over_budget?(setting)).to be false
    end

    it "returns false when spent equals budget (soft warning only)" do
      allow(described_class).to receive(:month_spent).and_return(100.0)
      # HARD_CAP = 2.0, так что 100 < 200 → false
      expect(described_class.over_budget?(setting)).to be false
    end

    it "returns true when spent >= budget × HARD_CAP_MULTIPLIER (2x)" do
      allow(described_class).to receive(:month_spent).and_return(200.0)
      expect(described_class.over_budget?(setting)).to be true
    end

    it "returns true when wildly over (e.g. 5x budget)" do
      allow(described_class).to receive(:month_spent).and_return(1_000.0)
      expect(described_class.over_budget?(setting)).to be true
    end
  end

  describe ".block_reason" do
    it "returns human-readable message with spent + budget + multiplier" do
      allow(described_class).to receive(:month_spent).and_return(250.0)
      reason = described_class.block_reason(setting)
      expect(reason).to include("budget_exceeded")
      expect(reason).to include("$250.0")
      expect(reason).to include("$100.0")
      expect(reason).to include("hard cap")
      expect(reason).to include("Settings → AI")
    end
  end

  describe ".month_spent" do
    it "sums cost_usd of AiRuns created since beginning of month" do
      allow(AiRun).to receive_message_chain(:where, :sum).and_return(42.5)
      expect(described_class.month_spent).to eq(42.5)
    end

    it "caches the SQL sum for 60s" do
      allow(AiRun).to receive_message_chain(:where, :sum).and_return(10.0, 999.0)
      first  = described_class.month_spent
      second = described_class.month_spent
      expect(first).to eq(10.0)
      expect(second).to eq(10.0)  # 999.0 should NOT be returned — cached
    end

    it "re-queries after invalidate_cache!" do
      allow(AiRun).to receive_message_chain(:where, :sum).and_return(10.0, 50.0)
      expect(described_class.month_spent).to eq(10.0)
      described_class.invalidate_cache!
      expect(described_class.month_spent).to eq(50.0)
    end
  end
end
