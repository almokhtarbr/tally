module TallyAnalytics
  class Configuration
    attr_accessor :api_key, :endpoint, :timeout, :batch_size, :flush_interval

    def initialize
      @timeout = 5
      @batch_size = 50
      @flush_interval = 5.0
    end
  end
end
