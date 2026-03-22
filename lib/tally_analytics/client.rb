require "net/http"
require "json"
require "uri"
require "time"

module TallyAnalytics
  class Client
    def initialize(config)
      @config = config
      @mutex = Mutex.new
      @queue = []
      @batch_size = config.batch_size || 50
      @flush_interval = config.flush_interval || 5.0

      start_flush_thread
    end

    def track(user_id, event_name, **properties)
      payload = {
        event: event_name,
        user_id: user_id,
        properties: properties,
        timestamp: Time.now.utc.iso8601
      }

      @mutex.synchronize do
        @queue << payload
        flush_locked if @queue.size >= @batch_size
      end
    end

    def identify(user_id, **properties)
      post("/api/v1/identify", {
        user_id: user_id,
        properties: properties
      })
    end

    def create_alias(anonymous_id, user_id)
      post("/api/v1/alias", {
        anonymous_id: anonymous_id,
        user_id: user_id
      })
    end

    def flush
      @mutex.synchronize { flush_locked }
    end

    def shutdown
      @running = false
      flush
      @flush_thread&.join(10)
      @pending_threads.each { |t| t.join(5) }
    end

    private

    def start_flush_thread
      @running = true
      @pending_threads = []
      @flush_thread = Thread.new do
        while @running
          sleep @flush_interval
          @mutex.synchronize do
            flush_locked if @queue.any?
          end
        end
      end
      @flush_thread.abort_on_exception = false
    end

    def flush_locked
      return if @queue.empty?

      events = @queue.shift(100) # API limit
      t = Thread.new do
        send_batch(events)
      end
      @pending_threads << t
    end

    def send_batch(events)
      post("/api/v1/batch", { events: events })
    rescue => e
      log_warn("Batch send failed: #{e.class}: #{e.message}")
    end

    def post(path, body)
      return log_warn("TallyAnalytics not configured") unless @config&.api_key && @config&.endpoint

      endpoint = @config.endpoint
      api_key = @config.api_key
      timeout = @config.timeout

      uri = URI.parse("#{endpoint}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = timeout
      http.read_timeout = timeout

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      request["X-API-Key"] = api_key
      request.body = body.to_json

      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPAccepted)
        log_warn("HTTP #{response.code}: #{response.body}")
      end
    rescue => e
      log_warn("#{e.class}: #{e.message}")
    end

    def log_warn(msg)
      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger.warn("[TallyAnalytics] #{msg}")
      else
        $stderr.puts("[TallyAnalytics] #{msg}")
      end
    end
  end
end
