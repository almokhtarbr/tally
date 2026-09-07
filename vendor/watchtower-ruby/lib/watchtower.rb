# Watchtower client — captures exceptions and ships them to a Watchtower
# service over HTTP. Self-contained and framework-agnostic at its core; only
# watchtower/railtie.rb touches Rails, and it is loaded only when Rails is
# present. Packaged as the `watchtower-ruby` gem.
#
# Every public entry point is wrapped so a Watchtower failure can never raise
# into, or slow down, the host app. Delivery is always async (a bounded queue
# drained by one background thread); request threads never do network IO.

require "watchtower/version"
require "watchtower/configuration"
require "watchtower/context"
require "watchtower/breadcrumbs"
require "watchtower/backtrace"
require "watchtower/event"
require "watchtower/transport"
require "watchtower/client"
require "watchtower/log_sink"
require "watchtower/custom_metrics"

module Watchtower
  class << self
    def configure
      yield config if block_given?
      config
    end

    def config
      @config ||= Configuration.new
    end

    def enabled?
      config.url.present? && config.public_key.present? &&
        config.enabled_environments.include?(config.environment)
    end

    # Report an exception. `context:` is merged into the event's context hash.
    # `fingerprint:` (array) overrides grouping — use it for synthetic errors
    # like a failed deploy, so every occurrence for the same app groups together.
    def notify(exception, context: {}, level: "error", fingerprint: nil)
      return unless enabled?
      client.capture(exception, context: context, level: level, fingerprint: fingerprint)
      nil
    rescue Exception => e # rubocop:disable Lint/RescueException
      log("notify failed: #{e.class}: #{e.message}")
      nil
    end

    def client
      @client ||= Client.new(config)
    end

    # Application metrics — buffered per minute, flushed to /custom_metrics.
    def metrics
      @metrics ||= CustomMetrics.new(config)
    end

    def increment(name, by: 1, tags: {}) = enabled? && metrics.increment(name, by: by, tags: tags)
    def gauge(name, value, tags: {})     = enabled? && metrics.gauge(name, value, tags: tags)
    def measure(name, value, tags: {})   = enabled? && metrics.measure(name, value, tags: tags)

    def time(name, tags: {}, &block)
      return yield unless enabled?
      metrics.time(name, tags: tags, &block)
    end

    # Record a deploy in Watchtower — links errors to the release and (when
    # resolve_issues: true) marks issues fixed that haven't been seen since.
    def track_deploy(version:, environment: nil, ref: nil, deployer: nil, resolve_issues: false,
                     repository: nil, commits: nil)
      return unless enabled?
      payload = {
        version: version.to_s,
        environment: (environment || config.environment).to_s,
        ref: ref, deployer: deployer,
        resolve_issues: resolve_issues,
        deployed_at: Time.now.utc.iso8601
      }
      payload[:repository] = repository.to_s unless repository.to_s.empty?
      payload[:commits] = Array(commits).first(200) unless Array(commits).empty?
      client.transport.deliver_deploy(payload)
      nil
    rescue Exception => e # rubocop:disable Lint/RescueException
      log("track_deploy failed: #{e.class}: #{e.message}")
      nil
    end

    def log(message)
      config.logger&.debug("[watchtower] #{message}")
    rescue StandardError
      nil
    end

    # Memoised structured-log sink. Also the target for Rails.logger
    # broadcasting when config.capture_logs is on (see the initializer).
    def log_sink
      @log_sink ||= LogSink.new(config)
    end

    # Send one structured log line. Works whether or not capture_logs is on.
    #   Watchtower.log_line("charged card", level: :info, amount: 20, plan: "pro")
    def log_line(message, level: :info, logger: nil, **fields)
      return unless enabled?
      log_sink.record(level, message, logger, fields)
      nil
    rescue Exception => e # rubocop:disable Lint/RescueException
      log("log_line failed: #{e.class}: #{e.message}")
      nil
    end

    # Record a breadcrumb from application code:
    #   Watchtower.log_breadcrumb("charged card", category: "billing", data: { amount: 20 })
    def log_breadcrumb(message, category: "custom", type: "default", data: nil)
      Breadcrumbs.add(message: message, category: category, type: type, data: data)
    rescue StandardError
      nil
    end

    # Test hook — drop memoized state.
    def reset!
      @config = nil
      @client = nil
      @log_sink = nil
      @metrics = nil
    end
  end
end

# Rails wiring lives in the Railtie so the host app only supplies config.
require "watchtower/railtie" if defined?(::Rails::Railtie)
