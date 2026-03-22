require "rails_helper"

RSpec.describe "POST /api/v1/alias", type: :request do
  let(:project) { create(:project) }

  it "creates an alias and returns 202" do
    post "/api/v1/alias",
      params: { anonymous_id: "anon_123", user_id: "user@test.com" }.to_json,
      headers: api_headers(project.api_key)

    expect(response).to have_http_status(:accepted)
    expect(IdentityAlias.last.anonymous_id).to eq("anon_123")
  end

  it "enqueues identity resolution job" do
    expect {
      post "/api/v1/alias",
        params: { anonymous_id: "anon_123", user_id: "user@test.com" }.to_json,
        headers: api_headers(project.api_key)
    }.to have_enqueued_job(IdentityResolutionJob)
  end

  it "returns 400 when anonymous_id is missing" do
    post "/api/v1/alias",
      params: { user_id: "user@test.com" }.to_json,
      headers: api_headers(project.api_key)

    expect(response).to have_http_status(:bad_request)
  end
end
