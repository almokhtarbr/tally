require "rails_helper"

RSpec.describe "Users Management", type: :request do
  let!(:admin) { create(:user, role: "admin") }
  let!(:member) { create(:user, role: "member", name: "Member User") }

  describe "admin access" do
    before { sign_in(admin) }

    it "GET /users lists users" do
      get users_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin.email)
    end

    it "GET /users/new returns 200" do
      get new_user_path
      expect(response).to have_http_status(:ok)
    end

    it "POST /users creates a user" do
      expect {
        post users_path, params: {
          user: { email: "new@example.com", name: "New User", password: "password123", password_confirmation: "password123", role: "member" }
        }
      }.to change(User, :count).by(1)
      expect(response).to redirect_to(users_path)
    end

    it "POST /users rejects invalid user" do
      post users_path, params: {
        user: { email: "", name: "", password: "x", password_confirmation: "y", role: "member" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "GET /users/:id/edit returns 200" do
      get edit_user_path(member)
      expect(response).to have_http_status(:ok)
    end

    it "PATCH /users/:id updates user" do
      patch user_path(member), params: { user: { name: "Updated Name" } }
      expect(response).to redirect_to(users_path)
      expect(member.reload.name).to eq("Updated Name")
    end

    it "PATCH /users/:id skips blank password" do
      patch user_path(member), params: { user: { name: "Same", password: "", password_confirmation: "" } }
      expect(response).to redirect_to(users_path)
    end

    it "DELETE /users/:id removes user" do
      expect {
        delete user_path(member)
      }.to change(User, :count).by(-1)
      expect(response).to redirect_to(users_path)
    end
  end

  describe "member access" do
    before { sign_in(member) }

    it "cannot access user index" do
      get users_path
      expect(response).to redirect_to(root_path)
    end

    it "cannot create users" do
      post users_path, params: {
        user: { email: "x@x.com", name: "X", password: "password123", password_confirmation: "password123", role: "member" }
      }
      expect(response).to redirect_to(root_path)
    end

    it "cannot delete users" do
      delete user_path(admin)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "profile editing" do
    before { sign_in(member) }

    it "GET /users/edit_profile returns 200" do
      get edit_profile_users_path
      expect(response).to have_http_status(:ok)
    end

    it "PATCH /users/update_profile updates own profile" do
      patch update_profile_users_path, params: { user: { name: "New Name" } }
      expect(response).to redirect_to(root_path)
      expect(member.reload.name).to eq("New Name")
    end
  end
end
