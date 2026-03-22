require "rails_helper"

RSpec.describe "POST /api/v1/track", type: :request do
  let(:project) { create(:project) }

  it "tracks an event and returns 202" do
    post "/api/v1/track",
      params: { event: "signup", user_id: "user@test.com" }.to_json,
      headers: api_headers(project.api_key)

    expect(response).to have_http_status(:accepted)
    expect(Event.last.name).to eq("signup")
  end

  it "tracks an event without user_id" do
    post "/api/v1/track",
      params: { event: "page_view" }.to_json,
      headers: api_headers(project.api_key)

    expect(response).to have_http_status(:accepted)
  end

  it "tracks with properties" do
    post "/api/v1/track",
      params: { event: "purchase", user_id: "user@test.com", properties: { plan: "pro" } }.to_json,
      headers: api_headers(project.api_key)

    expect(response).to have_http_status(:accepted)
    expect(Event.last.properties["plan"]).to eq("pro")
  end

  it "returns 401 with invalid API key" do
    post "/api/v1/track",
      params: { event: "test" }.to_json,
      headers: api_headers("pk_invalid")

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 400 when event name is missing" do
    post "/api/v1/track",
      params: {}.to_json,
      headers: api_headers(project.api_key)

    expect(response).to have_http_status(:bad_request)
  end
end
