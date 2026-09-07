require "logger"
require "time"

module Watchtower
  # A Logger-shaped sink. When config.capture_logs is on it is attached via
  # Rails.logger.broadcast_to and receives every log line; it also backs
  # Watchtower.log_line for explicit structured entries. Buffers lines and
  # ships them in batches through the shared Transport. Never raises into
  # the host logger; drops the oldest line when the buffer is full.
  class LogSink < ::Logger
    LEVELS     = %w[debug info warn error fatal unknown].freeze
    BATCH_SIZE = 50
    TICK       = 5

    def initialize(config)
      super(nil)
      @config = config
      @buffer = []
      @mutex  = Mutex.new
      @pid    = nil
      @thread = nil
      self.level = LEVELS.index(@config.log_level.to_s) || ::Logger::INFO
      install_at_exit
    end

    # Logger entry point (used by broadcasting and the level helpers).
    def add(severity, message = nil, progname = nil)
      severity ||= ::Logger::UNKNOWN
      return true if severity < level

      text = (message || (block_given? ? yield : progname)).to_s
      return true if text.empty? || text.start_with?("[watchtower]") # never loop on our own logs

      name = message.nil? ? nil : progname
      record(LEVELS[severity] || "unknown", text, name)
      true
    rescue Exception # rubocop:disable Lint/RescueException
      true
    end

    # Explicit structured entry.
    def record(level, message, logger_name = nil, fields = {})
      msg = message.to_s
      return if msg.strip.empty?

      ensure_worker
      line = {
        timestamp:  Time.now.utc.iso8601,
        level:      level.to_s,
        message:    msg,
        logger:     logger_name,
        request_id: current_request_id,
      }.compact
      line[:fields] = fields if fields && !fields.empty?

      full = false
      @mutex.synchronize do
        @buffer.shift while @buffer.size >= @config.log_queue_max
        @buffer << line
        full = @buffer.size >= BATCH_SIZE
      end
      flush_now if full
      nil
    rescue Exception => e # rubocop:disable Lint/RescueException
      Watchtower.log("log_sink record failed: #{e.class}: #{e.message}")
      nil
    end

    def flush_now
      batch = @mutex.synchronize { b = @buffer; @buffer = []; b }
      return if batch.empty?

      Watchtower.client.transport.deliver_logs(lines: batch)
    rescue Exception => e # rubocop:disable Lint/RescueException
      Watchtower.log("log_sink flush failed: #{e.class}: #{e.message}")
    end

    private

    def current_request_id
      req = Watchtower::Context[:request]
      req && (req[:request_id] || req["request_id"])
    rescue StandardError
      nil
    end

    # One daemon thread, recreated after a fork (Puma workers).
    def ensure_worker
      return if @pid == Process.pid && @thread&.alive?

      @mutex.synchronize do
        next if @pid == Process.pid && @thread&.alive?
        @pid = Process.pid
        @buffer = []
        @thread = Thread.new do
          loop do
            sleep TICK
            flush_now
          end
        rescue Exception # rubocop:disable Lint/RescueException
          nil
        end
        @thread.name = "watchtower-logsink"
        @thread.report_on_exception = false
      end
    end

    def install_at_exit
      at_exit { flush_now }
    rescue StandardError
      nil
    end
  end
end
