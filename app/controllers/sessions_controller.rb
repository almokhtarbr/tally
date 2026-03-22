class SessionsController < ApplicationController
  include Authentication

  layout "session"

  skip_before_action :authenticate!, only: [:new, :create]

  def new
    redirect_to root_path if signed_in?
  end

  def create
    user = User.find_by(email: params[:email]&.downcase&.strip)
    if user&.authenticate(params[:password])
      start_new_session(user, request: request)
      redirect_to root_path, notice: "Signed in."
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    end_session
    redirect_to new_session_path, notice: "Signed out."
  end
end
