require "active_support/concern"

module TallyAnalytics
  module RequestContext
    extend ActiveSupport::Concern

    included do
      around_action :set_tally_request_context
      rescue_from Exception, with: :tally_capture_and_reraise
    end

    private

    def set_tally_request_context
      Thread.current[:tally_request_context] = {
        controller: controller_name,
        action: action_name,
        path: request.path,
        method: request.method,
        user_id: (current_user.id.to_s if respond_to?(:current_user, true) && current_user rescue nil),
        params: request.filtered_parameters.except("controller", "action", "format").presence
      }
      yield
    ensure
      Thread.current[:tally_request_context] = nil
    end

    def tally_capture_and_reraise(exception)
      ctx = Thread.current[:tally_request_context] || {}

      backtrace = (exception.backtrace || []).first(30).join("\n")

      properties = {
        exception_class: exception.class.name,
        message: exception.message.to_s[0, 500],
        stack: backtrace[0, 4096],
        error_type: exception.class.name,
        controller: ctx[:controller],
        action: ctx[:action],
        request_path: ctx[:path],
        http_method: ctx[:method],
        params: ctx[:params].to_s[0, 1000]
      }.compact

      user_id = ctx[:user_id]

      TallyAnalytics.track(user_id, "$server_error", **properties)
    rescue => e
      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger.warn("[TallyAnalytics] Error capture failed: #{e.message}")
      end
    ensure
      raise exception
    end
  end
end
