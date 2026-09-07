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
      # TLS: verify by default. WATCHTOWER_SSL_VERIFY=0 (or WATCHTOWER_INSECURE=1)
      # skips verification — for reaching an instance behind a private CA / a
      # not-yet-issued public cert on a trusted network. WATCHTOWER_CA_FILE
      # points at a bundle to trust instead.
      @ssl_verify  = !(%w[0 false no off].include?(ENV["WATCHTOWER_SSL_VERIFY"].to_s.downcase) ||
                       %w[1 true yes on].include?(ENV["WATCHTOWER_INSECURE"].to_s.downcase))
      @ca_file     = ENV["WATCHTOWER_CA_FILE"].presence
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

      # Structured log forwarding. On by default now — a monitored app whose
      # logs don't reach the dashboard is half-blind, which is the opposite of
      # what the competitors ship. Opt out with WATCHTOWER_CAPTURE_LOGS=0.
      @capture_logs   = !%w[0 false no off].include?(ENV["WATCHTOWER_CAPTURE_LOGS"].to_s.downcase)
      @log_level      = (ENV["WATCHTOWER_LOG_LEVEL"].presence || "info").downcase
      @log_queue_max  = Integer(ENV.fetch("WATCHTOWER_LOG_QUEUE_MAX", 2_000))

      # Performance monitoring — on by default, but only slow traces ship
      # unless a sample rate is set. Cheap: one thread-local array per request.
      @perf_enabled = !%w[0 false no off].include?(ENV["WATCHTOWER_PERF"].to_s.downcase)
      @perf_slow_threshold_ms = Integer(ENV.fetch("WATCHTOWER_PERF_SLOW_MS", 500))
      @perf_sample_rate = Float(ENV.fetch("WATCHTOWER_PERF_SAMPLE_RATE", 0.0))
      @perf_max_spans = Integer(ENV.fetch("WATCHTOWER_PERF_MAX_SPANS", 500))
      @perf_instrument_http = !%w[0 false no off].include?(ENV["WATCHTOWER_PERF_HTTP"].to_s.downcase)

      # Report every unhandled Active Job exception as an error (Sidekiq/Solid
      # Queue). The trace already flags it; this makes the crash itself show up
      # in Issues like a request 500 would.
      @capture_job_errors = !%w[0 false no off].include?(ENV["WATCHTOWER_JOB_ERRORS"].to_s.downcase)

      # Minutely host/process probe — RSS, GC, threads, DB pool, load average —
      # the "host metrics" panel every competitor has. Opt out with
      # WATCHTOWER_PROBE=0.
      @probe_enabled  = !%w[0 false no off].include?(ENV["WATCHTOWER_PROBE"].to_s.downcase)
      @probe_interval = Integer(ENV.fetch("WATCHTOWER_PROBE_INTERVAL", 60))

      # How to identify the current user on an event. Default: Warden (Devise)
      # then a `Current.user`-style model. Override with
      # `config.user_context = ->(env) { { id: ..., email: ... } }`.
      @user_context = nil
    end

    attr_accessor :capture_job_errors, :probe_enabled, :probe_interval, :user_context,
                  :ssl_verify, :ca_file

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
