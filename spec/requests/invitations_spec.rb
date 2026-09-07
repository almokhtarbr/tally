require "rails_helper"

RSpec.describe "Invitations", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  # An admin already exists so require_setup is satisfied.
  let!(:admin) { create(:user, email: "admin@acme.test") }
  let(:invitee) { create(:user, :invited, email: "newbie@acme.test", name: "Newbie") }

  def token = invitee.generate_token_for(:invitation)

  describe "GET /invitations/:token" do
    it "renders the set-password form for a valid token" do
      get edit_invitation_path(token: token)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("newbie@acme.test")
    end

    it "rejects a garbage token" do
      get edit_invitation_path(token: "nope")
      expect(response).to redirect_to(new_session_path)
    end

    it "expires after 7 days" do
      t = token
      travel 8.days do
        get edit_invitation_path(token: t)
        expect(response).to redirect_to(new_session_path)
      end
    end

    it "is refused once the invitation is already accepted" do
      t = token
      invitee.update!(invitation_accepted_at: Time.current)
      get edit_invitation_path(token: t)
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "PATCH /invitations/:token" do
    it "sets the password, marks it accepted, and signs the user in" do
      patch invitation_path(token: token), params: {
        name: "Newbie Real", password: "chosenpass1", password_confirmation: "chosenpass1"
      }

      expect(response).to redirect_to(root_path)
      invitee.reload
      expect(invitee.authenticate("chosenpass1")).to be_truthy
      expect(invitee.invitation_pending?).to be(false)
      expect(invitee.name).to eq("Newbie Real")
      expect(invitee.sessions.count).to eq(1)
    end

    it "re-renders on a mismatched confirmation" do
      patch invitation_path(token: token), params: {
        password: "chosenpass1", password_confirmation: "different2"
      }
      expect(response).to have_http_status(:unprocessable_content)
      expect(invitee.reload.invitation_pending?).to be(true)
    end

    it "can't be replayed after acceptance" do
      t = token
      patch invitation_path(token: t), params: { password: "firstpass12", password_confirmation: "firstpass12" }
      reset!
      get edit_invitation_path(token: t)
      expect(response).to redirect_to(new_session_path)
    end
  end
end
