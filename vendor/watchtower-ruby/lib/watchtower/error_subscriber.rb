module Watchtower
  # Subscriber for Rails.error (Rails.error.handle/record and framework-reported
  # errors, including Active Job / Solid Queue). Deduped against the Rack path by
  # the exception object's own captured flag.
  class ErrorSubscriber
    def report(error, handled:, severity:, context:, source: nil)
      level = severity == :warning ? "warning" : "error"
      Watchtower.notify(
        error,
        context: (context || {}).merge(handled: handled, severity: severity, source: source),
        level: level
      )
    rescue Exception => e # rubocop:disable Lint/RescueException
      Watchtower.log("subscriber failed: #{e.class}: #{e.message}")
    end
  end
end
