require "rails_helper"

RSpec.describe "API Queries", type: :request do
  let(:project) { create(:project) }

  describe "GET /api/v1/queries/event_counts" do
    before do
      create(:event_daily_rollup, project: project, event_name: "signup", date: Date.current, count: 5)
      create(:event_daily_rollup, project: project, event_name: "signup", date: 1.day.ago.to_date, count: 3)
    end

    it "returns event counts by date" do
      get "/api/v1/queries/event_counts",
        params: { event: "signup", from: 7.days.ago.to_date, to: Date.current },
        headers: bearer_headers(project.api_secret)

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["data"]).to be_an(Array)
    end

    it "returns 401 without Bearer token" do
      get "/api/v1/queries/event_counts",
        params: { event: "signup" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "requires event parameter" do
      get "/api/v1/queries/event_counts",
        params: { from: 7.days.ago.to_date, to: Date.current },
        headers: bearer_headers(project.api_secret)

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "GET /api/v1/queries/top_events" do
    before do
      create(:event_daily_rollup, project: project, event_name: "signup", date: Date.current, count: 10)
      create(:event_daily_rollup, project: project, event_name: "purchase", date: Date.current, count: 5)
    end

    it "returns top events sorted by count" do
      get "/api/v1/queries/top_events",
        params: { from: 7.days.ago.to_date, to: Date.current },
        headers: bearer_headers(project.api_secret)

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["data"]).to be_an(Array)
      expect(data["data"].first["event"]).to eq("signup")
    end
  end

  describe "GET /api/v1/queries/user_timeline" do
    let(:user_profile) { create(:user_profile, project: project) }

    before do
      create(:event, project: project, user_profile: user_profile, name: "page_view", occurred_at: 1.hour.ago)
    end

    it "returns user events" do
      get "/api/v1/queries/user_timeline",
        params: { user_id: user_profile.external_id },
        headers: bearer_headers(project.api_secret)

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["data"]).to be_an(Array)
    end

    it "requires user_id" do
      get "/api/v1/queries/user_timeline",
        headers: bearer_headers(project.api_secret)

      expect(response).to have_http_status(:bad_request)
    end
  end
end
