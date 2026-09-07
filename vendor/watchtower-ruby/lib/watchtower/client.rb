module Watchtower
  class Client
    def initialize(config)
      @config = config
      @transport = Transport.new(config)
    end

    attr_reader :transport

    def capture(exception, context: {}, level: "error", fingerprint: nil)
      return if exception.nil?
      return if already_captured?(exception)
      return if ignored?(exception)
      return if sampled_out?
      return unless run_before_notify(exception, context)

      mark_captured(exception)
      payload = Event.build(exception, config: @config, context: context,
                            level: level, fingerprint: fingerprint)
      @transport.deliver(payload)
      nil
    rescue Exception => e # rubocop:disable Lint/RescueException
      Watchtower.log("capture failed: #{e.class}: #{e.message}")
      nil
    end

    private

    def ignored?(exception)
      return true if @config.ignored_exceptions.include?(exception.class.name)
      msg = exception.message.to_s
      Array(@config.ignore_messages).any? { |re| re.is_a?(Regexp) ? re.match?(msg) : msg.include?(re.to_s) }
    end

    # Any before_notify hook returning false/nil drops the event.
    def run_before_notify(exception, context)
      Array(@config.before_notify_hooks).all? do |hook|
        hook.call(exception, context) != false
      rescue StandardError
        true
      end
    end

    def sampled_out?
      @config.sample_rate < 1.0 && rand > @config.sample_rate
    end

    def already_captured?(exception)
      exception.instance_variable_defined?(:@__watchtower_captured)
    end

    def mark_captured(exception)
      exception.instance_variable_set(:@__watchtower_captured, true)
    rescue StandardError
      nil
    end
  end
end
