module TallyAnalytics
  class Railtie < Rails::Railtie
    initializer "tally_analytics.request_context" do
      ActiveSupport.on_load(:action_controller_base) do
        include TallyAnalytics::RequestContext
      end
    end
  end
end
