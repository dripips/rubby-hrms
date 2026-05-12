require "rails_helper"

RSpec.describe "Telegram Webhook", type: :request do
  before(:all) { Rails.application.load_seed }

  let(:user) { User.find_by!(email: "alice@hrms.local") }
  let(:secret) { "test-secret-token-xyz" }
  let(:company) { Company.kept.first }

  before do
    setting = AppSetting.fetch(company: company, category: "communication")
    setting.update!(data: setting.data.to_h.merge(
      "telegram_bot_token"      => "12345:fake",
      "telegram_webhook_secret" => secret
    ))
  end

  let(:payload) do
    {
      message: {
        chat: { id: 9_999_999 },
        text: text
      }
    }
  end
  let(:text) { "/start sometoken" }

  describe "POST /telegram/webhook" do
    context "without X-Telegram-Bot-Api-Secret-Token header" do
      it "returns 401" do
        post "/telegram/webhook", params: payload, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with wrong secret" do
      it "returns 401" do
        post "/telegram/webhook",
             params: payload, as: :json,
             headers: { "X-Telegram-Bot-Api-Secret-Token" => "WRONG" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with correct secret + /start <token> + matching user" do
      let(:link_token) { "valid-link-token-abc" }
      before do
        user.update!(tg_link_token: link_token, tg_link_token_at: 1.minute.ago)
        # Стабим HTTP-вызов sendMessage чтобы не дёргать Telegram API.
        allow(Net::HTTP).to receive(:post).and_return(double(is_a?: true))
      end
      let(:text) { "/start #{link_token}" }

      it "saves chat_id on the user and zeroes the token" do
        post "/telegram/webhook",
             params: payload, as: :json,
             headers: { "X-Telegram-Bot-Api-Secret-Token" => secret }
        expect(response).to have_http_status(:ok)
        user.reload
        expect(user.telegram_chat_id).to eq("9999999")
        expect(user.tg_link_token).to be_nil
        expect(user.tg_link_token_at).to be_nil
      end

      it "sends a confirmation message back to the user" do
        expect(Net::HTTP).to receive(:post) do |uri, body, headers|
          expect(uri.to_s).to include("api.telegram.org/bot12345:fake/sendMessage")
          parsed = JSON.parse(body)
          expect(parsed["chat_id"]).to eq("9999999")
          expect(parsed["text"]).to include(user.email)
          double(is_a?: true)
        end
        post "/telegram/webhook",
             params: payload, as: :json,
             headers: { "X-Telegram-Bot-Api-Secret-Token" => secret }
      end
    end

    context "with correct secret but expired token (>10 min)" do
      let(:link_token) { "expired-token" }
      before do
        user.update!(tg_link_token: link_token, tg_link_token_at: 15.minutes.ago)
        allow(Net::HTTP).to receive(:post).and_return(double(is_a?: true))
      end
      let(:text) { "/start #{link_token}" }

      it "does NOT bind chat_id (token expired)" do
        post "/telegram/webhook",
             params: payload, as: :json,
             headers: { "X-Telegram-Bot-Api-Secret-Token" => secret }
        expect(response).to have_http_status(:ok)
        user.reload
        expect(user.telegram_chat_id).to be_blank
      end
    end

    context "with correct secret but unknown token" do
      let(:text) { "/start gibberish-no-match" }
      before { allow(Net::HTTP).to receive(:post).and_return(double(is_a?: true)) }

      it "does NOT bind any user but still returns 200 (Telegram doesn't retry)" do
        before_count = User.where.not(telegram_chat_id: nil).count
        post "/telegram/webhook",
             params: payload, as: :json,
             headers: { "X-Telegram-Bot-Api-Secret-Token" => secret }
        expect(response).to have_http_status(:ok)
        expect(User.where.not(telegram_chat_id: nil).count).to eq(before_count)
      end
    end

    context "with /start (no token)" do
      let(:text) { "/start" }
      before { allow(Net::HTTP).to receive(:post).and_return(double(is_a?: true)) }

      it "returns 200 (welcome reply, no binding)" do
        post "/telegram/webhook",
             params: payload, as: :json,
             headers: { "X-Telegram-Bot-Api-Secret-Token" => secret }
        expect(response).to have_http_status(:ok)
      end
    end

    context "always returns 200 on internal errors (Telegram doesn't retry)" do
      before do
        # Спровоцируем internal-error при обработке.
        allow(User).to receive(:where).and_raise(StandardError, "boom")
      end

      it "swallows exceptions, returns 200" do
        post "/telegram/webhook",
             params: payload, as: :json,
             headers: { "X-Telegram-Bot-Api-Secret-Token" => secret }
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
