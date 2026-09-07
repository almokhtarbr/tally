require "rails_helper"

RSpec.describe InvitationMailer, type: :mailer do
  let(:admin) { create(:user, name: "Ada", email: "ada@acme.test") }
  let(:invitee) { create(:user, :invited, email: "guest@acme.test") }

  describe "#invite" do
    subject(:mail) { described_class.invite(invitee, admin) }

    it "is addressed to the invitee with a clear subject" do
      expect(mail.to).to eq([ "guest@acme.test" ])
      expect(mail.subject).to eq("You've been invited to Tally")
    end

    it "names the inviter and carries a working invitation link" do
      text = mail.text_part.body.decoded
      expect(text).to include("Ada")

      link = text[%r{http://example\.com/invitations/\S+}]
      token = link.split("/invitations/").last
      expect(User.find_by_token_for!(:invitation, token)).to eq(invitee)
    end
  end
end
