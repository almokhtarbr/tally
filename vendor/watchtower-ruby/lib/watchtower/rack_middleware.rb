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

      if (exception = env["action_dispatch.exception"])
        Watchtower.notify(exception, context: { mechanism: "rack" })
      end

      response
    rescue Exception => e # rubocop:disable Lint/RescueException
      Watchtower.notify(e, context: { mechanism: "rack" })
      raise
    ensure
      Context.clear
    end

    private

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
