require "rails_helper"

RSpec.describe "POST /api/v1/identify", type: :request do
  let(:project) { create(:project) }

  it "creates a user profile and returns 202" do
    post "/api/v1/identify",
      params: { user_id: "user@test.com", properties: { name: "Jane" } }.to_json,
      headers: api_headers(project.api_key)

    expect(response).to have_http_status(:accepted)
    expect(UserProfile.last.external_id).to eq("user@test.com")
    expect(UserProfile.last.properties["name"]).to eq("Jane")
  end

  it "merges properties for existing user" do
    create(:user_profile, project: project, external_id: "user@test.com", properties: { "plan" => "free" })

    post "/api/v1/identify",
      params: { user_id: "user@test.com", properties: { name: "Jane" } }.to_json,
      headers: api_headers(project.api_key)

    expect(response).to have_http_status(:accepted)
    up = UserProfile.find_by(external_id: "user@test.com")
    expect(up.properties).to eq({ "plan" => "free", "name" => "Jane" })
  end

  it "returns 400 when user_id is missing" do
    post "/api/v1/identify",
      params: { properties: { name: "Jane" } }.to_json,
      headers: api_headers(project.api_key)

    expect(response).to have_http_status(:bad_request)
  end
end
