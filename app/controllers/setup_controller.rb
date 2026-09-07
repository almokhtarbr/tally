class SetupController < ApplicationController
  include Authentication

  layout "session"

  skip_before_action :authenticate!
  before_action :already_setup!

  def new
    @user = User.new
  end

  def create
    @user = User.new(setup_params)
    @user.role = "admin"
    @user.invitation_accepted_at = Time.current

    if @user.save
      start_new_session(@user, request: request)
      redirect_to root_path, notice: "Welcome to Tally! Your admin account has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def already_setup!
    redirect_to root_path if User.exists?
  end

  def setup_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
