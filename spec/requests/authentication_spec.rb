require "rails_helper"

RSpec.describe "Authentication", type: :request do
  describe "setup flow (no users exist)" do
    it "redirects to setup when no users exist" do
      get root_path
      expect(response).to redirect_to(setup_path)
    end

    it "shows setup form" do
      get setup_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Create your admin account")
    end

    it "creates admin account via setup" do
      expect {
        post setup_path, params: {
          user: { name: "Admin", email: "admin@test.com", password: "password123", password_confirmation: "password123" }
        }
      }.to change(User, :count).by(1)

      user = User.last
      expect(user.role).to eq("admin")
      expect(user.email).to eq("admin@test.com")
      expect(response).to redirect_to(root_path)
    end

    it "rejects invalid setup" do
      post setup_path, params: {
        user: { name: "", email: "", password: "short", password_confirmation: "mismatch" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "blocks setup when users already exist" do
      create(:user)
      get setup_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "session auth" do
    let!(:user) { create(:user, role: "admin") }

    it "redirects unauthenticated requests to login" do
      get root_path
      expect(response).to redirect_to(new_session_path)
    end

    it "allows access after login" do
      sign_in(user)
      get root_path
      expect(response).to have_http_status(:ok)
    end

    it "login with valid credentials sets session cookie" do
      post session_path, params: { email: user.email, password: "password123" }
      expect(response).to redirect_to(root_path)
      expect(cookies[:session_token]).to be_present
    end

    it "login with invalid credentials renders error" do
      post session_path, params: { email: user.email, password: "wrong" }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "logout clears session" do
      sign_in(user)
      delete destroy_session_path
      expect(response).to redirect_to(new_session_path)

      get root_path
      expect(response).to redirect_to(new_session_path)
    end

    it "creates a Session record on login" do
      expect {
        sign_in(user)
      }.to change(Session, :count).by(1)
    end

    it "destroys Session record on logout" do
      sign_in(user)
      expect {
        delete destroy_session_path
      }.to change(Session, :count).by(-1)
    end
  end

  describe "admin-only routes" do
    let!(:admin) { create(:user, role: "admin") }
    let!(:member) { create(:user, role: "member") }

    it "admin can access user management" do
      sign_in(admin)
      get users_path
      expect(response).to have_http_status(:ok)
    end

    it "member cannot access user management" do
      sign_in(member)
      get users_path
      expect(response).to redirect_to(root_path)
    end
  end
end
