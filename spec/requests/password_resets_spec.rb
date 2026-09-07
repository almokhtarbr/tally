require "rails_helper"

RSpec.describe "Password resets", type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let!(:user) { create(:user, email: "jane@acme.test", password: "oldpassword1", password_confirmation: "oldpassword1") }

  describe "POST /reset-password" do
    it "emails a link when the address exists" do
      expect {
        perform_enqueued_jobs { post password_resets_path, params: { email: "jane@acme.test" } }
      }.to change { ActionMailer::Base.deliveries.size }.by(1)
      expect(response).to redirect_to(new_session_path)
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ "jane@acme.test" ])
    end

    it "says the same thing (and sends nothing) for an unknown address" do
      expect {
        perform_enqueued_jobs { post password_resets_path, params: { email: "nobody@acme.test" } }
      }.not_to change { ActionMailer::Base.deliveries.size }
      expect(response).to redirect_to(new_session_path)
      follow_redirect!
      expect(response.body).to include("If that email is registered")
    end
  end

  describe "the reset link" do
    def token = user.generate_token_for(:password_reset)

    it "renders the form for a valid token" do
      get edit_password_reset_path(token: token)
      expect(response).to have_http_status(:ok)
    end

    it "sets a new password and logs the user out everywhere" do
      user.sessions.create!
      patch password_reset_path(token: token),
        params: { password: "brandnew123", password_confirmation: "brandnew123" }

      expect(response).to redirect_to(new_session_path)
      expect(user.reload.authenticate("brandnew123")).to be_truthy
      expect(user.sessions.count).to eq(0)
    end

    it "rejects a tampered / unknown token" do
      get edit_password_reset_path(token: "not-a-real-token")
      expect(response).to redirect_to(new_password_reset_path)
    end

    it "is single-use — the same link fails after the password changed" do
      old = token
      patch password_reset_path(token: old), params: { password: "firstchange1", password_confirmation: "firstchange1" }

      get edit_password_reset_path(token: old)
      expect(response).to redirect_to(new_password_reset_path)
    end

    it "expires after 30 minutes" do
      t = token
      travel 31.minutes do
        get edit_password_reset_path(token: t)
        expect(response).to redirect_to(new_password_reset_path)
      end
    end
  end
end
