require "securerandom"
require "socket"

module Watchtower
  # Builds the JSON-ready payload for POST /api/:key/events from an exception
  # plus the current Context. Applies key redaction defensively.
  class Event
    MAX_MESSAGE = 8_000

    def self.build(exception, config:, context: {}, level: "error", fingerprint: nil)
      new(exception, config, context, level, fingerprint).to_h
    end

    def initialize(exception, config, context, level, fingerprint = nil)
      @exception   = exception
      @config      = config
      @extra_ctx   = context || {}
      @level       = level.to_s
      @fingerprint = fingerprint
    end

    def to_h
      ctx = Context.to_h
      h = {
        event_id:    SecureRandom.uuid,
        timestamp:   Time.now.utc.iso8601,
        level:       @level,
        release:     @config.release,
        environment: @config.environment,
        server_name: hostname,
        transaction: transaction_name(ctx),
        exception: {
          class:     @exception.class.name,
          message:   full_message,
          backtrace: Backtrace.extract(@exception, root: @config.root),
          causes:    causes,
        }.compact,
        request: redact(ctx[:request]),
        context: redact(ctx.slice(:user, :tags).merge(extra: @extra_ctx)),
        breadcrumbs: breadcrumbs,
        sdk:     { name: "watchtower-ruby", version: "0.1.0" },
      }
      h[:fingerprint] = Array(@fingerprint) if @fingerprint
      h
    end

    # Include the cause chain in the message so "wrapped" errors read fully.
    def full_message
      msg = @exception.message.to_s
      chain = cause_chain
      msg += "\ncaused by " + chain.map { |c| "#{c.class.name}: #{c.message}" }.join("\ncaused by ") if chain.any?
      msg[0, MAX_MESSAGE]
    end

    def causes
      cause_chain.map do |c|
        { class: c.class.name, message: c.message.to_s[0, 2_000],
          backtrace: Backtrace.extract(c, root: @config.root).first(20) }
      end.presence
    end

    def cause_chain
      seen = { @exception.object_id => true }
      out = []
      cur = @exception.cause
      while cur && !seen[cur.object_id] && out.length < 5
        seen[cur.object_id] = true
        out << cur
        cur = cur.cause
      end
      out
    rescue StandardError
      []
    end

    def breadcrumbs
      Breadcrumbs.to_a
    rescue StandardError
      []
    end

    private

    def hostname
      Socket.gethostname
    rescue StandardError
      "unknown"
    end

    def transaction_name(ctx)
      ctx.dig(:request, :name) || ctx.dig(:job, :class) || nil
    end

    def redact(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(k, v), acc|
          acc[k] = k.to_s.match?(@config.redact_keys) ? "[FILTERED]" : redact(v)
        end
      when Array
        obj.map { |v| redact(v) }
      else
        obj
      end
    end
  end
end
