class PasswordMailer < ApplicationMailer
  def reset(user)
    @user  = user
    @token = user.generate_token_for(:password_reset)
    mail to: user.email, subject: "Reset your Tally password"
  end
end
