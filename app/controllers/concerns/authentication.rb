module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_setup
    before_action :authenticate!
    helper_method :current_user, :signed_in?
  end

  private

  def current_user
    Current.user
  end

  def signed_in?
    Current.session.present?
  end

  def authenticate!
    if (session_record = find_session_by_cookie)
      Current.session = session_record
    else
      redirect_to new_session_path
    end
  end

  def find_session_by_cookie
    return nil unless cookies.signed[:session_token]
    Session.find_by(token: cookies.signed[:session_token])
  end

  def start_new_session(user, request:)
    session_record = user.sessions.create!(
      ip_address: request.remote_ip,
      user_agent: request.user_agent.to_s.first(500)
    )
    cookies.signed.permanent[:session_token] = {
      value: session_record.token,
      httponly: true,
      same_site: :lax
    }
    Current.session = session_record
    session_record
  end

  def end_session
    find_session_by_cookie&.destroy
    cookies.delete(:session_token)
    Current.session = nil
  end

  def require_setup
    return if User.exists?
    return if self.class == SetupController

    redirect_to setup_path
  end
end
