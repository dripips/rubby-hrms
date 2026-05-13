require "rails_helper"

RSpec.describe "CSP violations endpoint", type: :request do
  it "accepts classic csp-report format and returns 204" do
    body = {
      "csp-report" => {
        "document-uri"       => "https://hrms.bobkov.cc/dashboard",
        "violated-directive" => "script-src",
        "blocked-uri"        => "https://evil.com/script.js",
        "source-file"        => "https://hrms.bobkov.cc/assets/app.js",
        "line-number"        => 42
      }
    }
    post "/csp_violations", params: body.to_json, headers: { "Content-Type" => "application/json" }
    expect(response).to have_http_status(:no_content)
  end

  it "accepts new reporting-api array format" do
    body = [ {
      "type" => "csp-violation",
      "body" => {
        "documentURL"        => "https://hrms.bobkov.cc/dashboard",
        "violatedDirective"  => "img-src",
        "blockedURL"         => "data:image/png;base64,iVBOR..."
      }
    } ]
    post "/csp_violations", params: body.to_json, headers: { "Content-Type" => "application/json" }
    expect(response).to have_http_status(:no_content)
  end

  it "tolerates empty body" do
    post "/csp_violations"
    expect(response).to have_http_status(:no_content)
  end

  it "tolerates malformed JSON without crashing" do
    post "/csp_violations", params: "not-json-at-all", headers: { "Content-Type" => "application/json" }
    expect(response).to have_http_status(:no_content)
  end

  it "reports violation through Rails.error" do
    expect(Rails.error).to receive(:report).with(
      "CSP violation",
      hash_including(severity: :info, handled: true, context: hash_including(kind: "csp_violation"))
    )

    body = { "csp-report" => { "violated-directive" => "script-src", "blocked-uri" => "https://evil.com" } }
    post "/csp_violations", params: body.to_json, headers: { "Content-Type" => "application/json" }
  end
end
