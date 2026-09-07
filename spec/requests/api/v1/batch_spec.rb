require "rails_helper"

RSpec.describe "POST /api/v1/batch", type: :request do
  let(:project) { create(:project) }

  it "tracks multiple events and returns 202" do
    events = [
      { event: "signup", user_id: "user1@test.com" },
      { event: "login", user_id: "user2@test.com" }
    ]

    post "/api/v1/batch",
      params: { events: events }.to_json,
      headers: api_headers(project.api_key)

    expect(response).to have_http_status(:accepted)
    expect(Event.count).to eq(2)
  end

  it "rejects batches over 100 events" do
    events = 101.times.map { |i| { event: "test", user_id: "user#{i}" } }

    post "/api/v1/batch",
      params: { events: events }.to_json,
      headers: api_headers(project.api_key)

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "returns 401 with invalid API key" do
    post "/api/v1/batch",
      params: { events: [ { event: "test" } ] }.to_json,
      headers: api_headers("pk_invalid")

    expect(response).to have_http_status(:unauthorized)
  end
end
