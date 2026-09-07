require "rails_helper"

RSpec.describe "Users", type: :request do
  include ActiveJob::TestHelper

  let!(:admin) { create(:user, role: "admin", email: "admin@acme.test") }

  before { sign_in(admin) }

  describe "POST /users" do
    it "emails an invitation when no password is given" do
      expect {
        perform_enqueued_jobs do
          post users_path, params: { user: { name: "Kim", email: "kim@acme.test", role: "member", password: "" } }
        end
      }.to change { ActionMailer::Base.deliveries.size }.by(1)

      kim = User.find_by(email: "kim@acme.test")
      expect(kim.invitation_pending?).to be(true)
      expect(ActionMailer::Base.deliveries.last.to).to eq([ "kim@acme.test" ])
      expect(response).to redirect_to(users_path)
    end

    it "creates an already-active user when a password is given" do
      expect {
        perform_enqueued_jobs do
          post users_path, params: { user: { name: "Sam", email: "sam@acme.test", role: "member",
            password: "sampass1234", password_confirmation: "sampass1234" } }
        end
      }.not_to change { ActionMailer::Base.deliveries.size }

      expect(User.find_by(email: "sam@acme.test").invitation_pending?).to be(false)
    end
  end

  describe "POST /users/:id/resend_invitation" do
    it "re-sends for a pending invite" do
      pending_user = create(:user, :invited, email: "wait@acme.test")
      expect {
        perform_enqueued_jobs { post resend_invitation_user_path(pending_user) }
      }.to change { ActionMailer::Base.deliveries.size }.by(1)
    end

    it "does nothing for a user who already accepted" do
      active = create(:user, email: "done@acme.test")
      expect {
        perform_enqueued_jobs { post resend_invitation_user_path(active) }
      }.not_to change { ActionMailer::Base.deliveries.size }
      expect(response).to redirect_to(users_path)
    end
  end

  it "keeps non-admins out of user management" do
    member = create(:user, role: "member", email: "member@acme.test")
    sign_in(member)
    post users_path, params: { user: { name: "X", email: "x@acme.test", role: "member" } }
    expect(response).to redirect_to(root_path)
  end
end
