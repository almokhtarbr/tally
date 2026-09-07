class InvitationMailer < ApplicationMailer
  def invite(user, invited_by)
    @user = user
    @invited_by = invited_by
    @token = user.generate_token_for(:invitation)
    mail to: user.email, subject: "You've been invited to Tally"
  end
end
