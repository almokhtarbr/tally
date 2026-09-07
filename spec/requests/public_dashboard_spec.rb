require "rails_helper"

RSpec.describe "Public dashboard", type: :request do
  let(:project) { create(:project, name: "Acme") }

  it "renders the headline numbers for a valid share token, no login" do
    project.enable_sharing!
    create(:event_daily_rollup, project:, event_name: "$pageview", date: 2.days.ago.to_date, count: 120)
    create(:event_daily_rollup, project:, event_name: "signup",    date: 2.days.ago.to_date, count: 7)

    get public_dashboard_path(project.share_token)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Acme").and include("120").and include("signup")
    expect(response.body).not_to include("API Secret") # not the full dashboard
  end

  it "404s for an unknown token" do
    get public_dashboard_path("sh_nope")
    expect(response).to have_http_status(:not_found)
  end

  it "404s once sharing is turned off" do
    project.enable_sharing!
    token = project.share_token
    project.disable_sharing!

    get public_dashboard_path(token)
    expect(response).to have_http_status(:not_found)
  end

  it "rotating the link invalidates the old one" do
    project.enable_sharing!
    old = project.share_token
    project.enable_sharing! # rotate

    get public_dashboard_path(old)
    expect(response).to have_http_status(:not_found)
    get public_dashboard_path(project.reload.share_token)
    expect(response).to have_http_status(:ok)
  end
end
