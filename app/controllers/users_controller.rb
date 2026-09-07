class UsersController < ApplicationController
  include Authentication

  before_action :require_admin!, except: [ :edit_profile, :update_profile ]

  def index
    @users = User.order(:name)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if invite_by_email?
      # No password typed: stash an unusable random one so the record is
      # valid, then email a link for the member to set their own.
      @user.password = @user.password_confirmation = SecureRandom.base58(24)
      if @user.save
        InvitationMailer.invite(@user, current_user).deliver_later
        redirect_to users_path, notice: "Invitation sent to #{@user.email}."
      else
        render :new, status: :unprocessable_entity
      end
    elsif @user.save
      @user.update_column(:invitation_accepted_at, Time.current)
      redirect_to users_path, notice: "User created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def resend_invitation
    user = User.find(params[:id])
    if user.invitation_pending?
      InvitationMailer.invite(user, current_user).deliver_later
      redirect_to users_path, notice: "Invitation resent to #{user.email}."
    else
      redirect_to users_path, alert: "#{user.name} has already accepted their invitation."
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
      update_digest_preferences
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

  def invite_by_email?
    params.dig(:user, :password).blank?
  end

  def user_params
    params.require(:user).permit(:email, :name, :password, :password_confirmation, :role)
  end

  def profile_params
    params.require(:user).permit(:name, :password, :password_confirmation)
  end

  # Checkboxes on the profile page toggle the weekly digest per project.
  # Absent param means the section wasn't shown (no memberships) — leave as is.
  def update_digest_preferences
    return unless params.key?(:weekly_digest_project_ids)

    wanted = Array(params[:weekly_digest_project_ids]).map(&:to_i)
    @user.project_memberships.find_each do |m|
      m.update_column(:weekly_digest, wanted.include?(m.project_id))
    end
  end
end
