require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let!(:user) { create(:user) }

  it "redirects to login without auth" do
    get root_path
    expect(response).to redirect_to(new_session_path)
  end

  it "returns 200 after login" do
    sign_in(user)
    get root_path
    expect(response).to have_http_status(:ok)
  end

  it "lists projects" do
    create(:project, name: "My App")
    sign_in(user)
    get root_path
    expect(response.body).to include("My App")
  end
end
