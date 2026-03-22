require_relative "tally_analytics/configuration"
require_relative "tally_analytics/client"
require_relative "tally_analytics/request_context"
require_relative "tally_analytics/railtie" if defined?(Rails::Railtie)

module TallyAnalytics
  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration)
    end

    def track(user_id, event_name, **properties)
      client.track(user_id, event_name, **properties)
    end

    def identify(user_id, **properties)
      client.identify(user_id, **properties)
    end

    def create_alias(anonymous_id, user_id)
      client.create_alias(anonymous_id, user_id)
    end

    private

    def client
      @client ||= Client.new(configuration)
    end
  end
end
