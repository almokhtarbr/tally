class InvitationsController < ApplicationController
  include Authentication

  layout "session"
  skip_before_action :authenticate!
  before_action :set_user_from_token

  def edit; end

  def update
    if @user.update(invitation_params.merge(invitation_accepted_at: Time.current))
      start_new_session(@user, request: request)
      redirect_to root_path, notice: "Welcome to Tally!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def invitation_params
    params.permit(:name, :password, :password_confirmation)
  end

  def set_user_from_token
    @user = User.find_by_token_for!(:invitation, params[:token])
    unless @user.invitation_pending?
      redirect_to new_session_path, alert: "That invitation has already been used — just sign in."
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    redirect_to new_session_path, alert: "That invitation link is invalid or has expired."
  end
end
