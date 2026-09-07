class PasswordResetsController < ApplicationController
  include Authentication

  layout "session"
  skip_before_action :authenticate!
  before_action :set_user_from_token, only: %i[edit update]

  def new; end

  # Always says "check your email" — never reveals whether the address exists.
  def create
    if (user = User.find_by(email: params[:email].to_s.downcase.strip))
      PasswordMailer.reset(user).deliver_later
    end
    redirect_to new_session_path, notice: "If that email is registered, a reset link is on its way."
  end

  def edit; end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      @user.sessions.delete_all # log out everywhere on a password change
      redirect_to new_session_path, notice: "Password updated. Sign in with your new password."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user_from_token
    @user = User.find_by_token_for!(:password_reset, params[:token])
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    redirect_to new_password_reset_path, alert: "That reset link is invalid or has expired."
  end
end
