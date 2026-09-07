module Watchtower
  # Captures unhandled exceptions from the request cycle, then re-raises the
  # original so Rails' own error handling is untouched. Populates Context with
  # request metadata for the duration of the request.
  class RackMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      Context[:request] = request_context(env)
      response = @app.call(env)

      Context[:user] = user_context(env)
      if (exception = env["action_dispatch.exception"])
        Watchtower.notify(exception, context: { mechanism: "rack" })
      end

      response
    rescue Exception => e # rubocop:disable Lint/RescueException
      Context[:user] ||= user_context(env)
      Watchtower.notify(e, context: { mechanism: "rack" })
      raise
    ensure
      Context.clear
    end

    private

    # The signed-in user, folded into every event from this request. A
    # host-supplied `config.user_context` proc wins; otherwise Warden (Devise)
    # then a `Current.user`-style model. Never triggers authentication that
    # hasn't already happened, never raises.
    def user_context(env)
      if (proc = Watchtower.config.user_context)
        u = proc.arity.zero? ? proc.call : proc.call(env)
        return normalize_user(u)
      end

      warden = env["warden"]
      user =
        if warden.respond_to?(:authenticated?) && warden.authenticated?
          warden.user
        elsif defined?(::Current) && ::Current.respond_to?(:user)
          ::Current.user
        end
      normalize_user(user)
    rescue StandardError
      nil
    end

    def normalize_user(user)
      return nil if user.nil?
      return user if user.is_a?(Hash)

      {
        id:    (user.try(:id) || user.try(:to_param)),
        email: (user.try(:email) || user.try(:email_address)),
        name:  (user.try(:name) || user.try(:username) || user.try(:display_name))
      }.compact.presence
    rescue StandardError
      nil
    end

    def request_context(env)
      req = Rack::Request.new(env)
      {
        name:   "#{req.request_method} #{route_pattern(env) || req.path}",
        method: req.request_method,
        url:    req.url,
        params: safe_params(req),
        ip:     req.ip,
        request_id: env["action_dispatch.request_id"],
      }
    rescue StandardError
      nil
    end

    def route_pattern(env)
      env["action_dispatch.route_uri_pattern"]
    end

    def safe_params(req)
      req.params.transform_values { |v| v.is_a?(String) ? v[0, 500] : v }
    rescue StandardError
      {}
    end
  end
end
