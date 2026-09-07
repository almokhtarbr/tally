module Watchtower
  class Configuration
    attr_accessor :url, :public_key, :environment, :enabled_environments,
                  :release, :timeout, :queue_max, :ignored_exceptions,
                  :ignore_messages, :sample_rate, :redact_keys, :root, :logger,
                  :capture_logs, :log_level, :log_queue_max,
                  :perf_enabled, :perf_slow_threshold_ms, :perf_sample_rate, :perf_max_spans,
                  :perf_instrument_http
    attr_reader :before_notify_hooks

    # config.before_notify { |exception, hint| ... return false/nil to drop }
    def before_notify(&block)
      (@before_notify_hooks ||= []) << block if block
    end

    def initialize
      @url         = ENV["WATCHTOWER_URL"].presence
      @public_key  = ENV["WATCHTOWER_PUBLIC_KEY"].presence
      @environment = ENV["WATCHTOWER_ENV"].presence || ENV["RAILS_ENV"].presence || "development"
      @enabled_environments = %w[production development]
      @release     = resolve_release
      @timeout     = Float(ENV.fetch("WATCHTOWER_TIMEOUT", 2))
      @queue_max   = Integer(ENV.fetch("WATCHTOWER_QUEUE_MAX", 100))
      @sample_rate = Float(ENV.fetch("WATCHTOWER_SAMPLE_RATE", 1.0))
      @ignored_exceptions = %w[
        ActiveRecord::RecordNotFound
        ActionController::RoutingError
        ActionController::InvalidAuthenticityToken
        ActionController::UnknownFormat
        SystemExit
        SignalException
      ]
      # Well-known noise that isn't a bug in this app.
      @ignore_messages = [
        /Broken pipe/i, /Connection reset by peer/i, /EOFError/i,
        /Rack::Timeout/i, /Puma::HttpParserError/i
      ]
      @redact_keys = /pass|secret|token|api[_-]?key|authorization|cookie|csrf/i
      @root        = Dir.pwd
      @logger      = nil
      @before_notify_hooks = []

      # Structured log forwarding — opt-in; noisy and PII-prone.
      @capture_logs   = %w[1 true yes].include?(ENV["WATCHTOWER_CAPTURE_LOGS"].to_s.downcase)
      @log_level      = (ENV["WATCHTOWER_LOG_LEVEL"].presence || "info").downcase
      @log_queue_max  = Integer(ENV.fetch("WATCHTOWER_LOG_QUEUE_MAX", 2_000))

      # Performance monitoring — on by default, but only slow traces ship
      # unless a sample rate is set. Cheap: one thread-local array per request.
      @perf_enabled = !%w[0 false no off].include?(ENV["WATCHTOWER_PERF"].to_s.downcase)
      @perf_slow_threshold_ms = Integer(ENV.fetch("WATCHTOWER_PERF_SLOW_MS", 500))
      @perf_sample_rate = Float(ENV.fetch("WATCHTOWER_PERF_SAMPLE_RATE", 0.0))
      @perf_max_spans = Integer(ENV.fetch("WATCHTOWER_PERF_MAX_SPANS", 500))
      @perf_instrument_http = !%w[0 false no off].include?(ENV["WATCHTOWER_PERF_HTTP"].to_s.downcase)
    end

    private

    def resolve_release
      ENV["WATCHTOWER_RELEASE"].presence ||
        ENV["KAMAL_VERSION"].presence ||
        ENV["FLY_MACHINE_VERSION"].presence ||
        (ENV["FLY_IMAGE_REF"].to_s[/deployment-\w+/]) ||
        (`git rev-parse --short HEAD 2>/dev/null`.strip.presence rescue nil) ||
        "unknown"
    end
  end
end
