class UsersController < ApplicationController
  include Authentication

  before_action :require_admin!, except: [:edit_profile, :update_profile]

  def index
    @users = User.order(:name)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to users_path, notice: "User invited."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @user = User.find(params[:id])
  end

  def update
    @user = User.find(params[:id])
    update_params = user_params
    update_params.delete(:password) if update_params[:password].blank?
    if @user.update(update_params)
      redirect_to users_path, notice: "User updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    user = User.find(params[:id])
    user.destroy
    redirect_to users_path, notice: "User removed."
  end

  def edit_profile
    @user = current_user
  end

  def update_profile
    @user = current_user
    if @user.update(profile_params)
      redirect_to root_path, notice: "Profile updated."
    else
      render :edit_profile, status: :unprocessable_entity
    end
  end

  private

  def require_admin!
    return if current_user&.admin?
    redirect_to root_path, alert: "Not authorized."
  end

  def user_params
    params.require(:user).permit(:email, :name, :password, :password_confirmation, :role)
  end

  def profile_params
    params.require(:user).permit(:name, :password, :password_confirmation)
  end
end
