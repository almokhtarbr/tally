require "net/http"
require "json"
require "uri"

module Watchtower
  # Async, fail-safe delivery. `deliver` drops the payload onto a bounded
  # in-memory queue and returns immediately — it never blocks and never
  # raises. One background thread drains the queue and POSTs. Fork-safe:
  # after a fork (Puma workers), the queue and thread are recreated lazily.
  class Transport
    def initialize(config)
      @config = config
      @mutex  = Mutex.new
      @queue  = []
      @dropped = 0
      @pid = nil
      @thread = nil
      install_at_exit
    end

    def deliver(payload)
      enqueue([ :events, payload ])
    end

    def deliver_metrics(payload)
      enqueue([ :metrics, payload ])
    end

    def deliver_deploy(payload)
      enqueue([ :deploys, payload ])
    end

    def deliver_logs(payload)
      enqueue([ :logs, payload ])
    end

    def deliver_transaction(payload)
      enqueue([ :transactions, payload ])
    end

    def deliver_custom_metrics(payload)
      enqueue([ :custom_metrics, payload ])
    end

    def dropped_count = @dropped

    # Block until the queue drains or the deadline passes. For tests / shutdown.
    def flush(timeout: 2.0)
      deadline = monotonic + timeout
      sleep(0.02) while pending? && monotonic < deadline
    end

    private

    def enqueue(item)
      ensure_worker
      @mutex.synchronize do
        if @queue.size >= @config.queue_max
          @dropped += 1
          Watchtower.log("queue full, dropped (total #{@dropped})")
        else
          @queue << item
        end
      end
      nil
    rescue Exception => e # rubocop:disable Lint/RescueException
      Watchtower.log("enqueue failed: #{e.class}: #{e.message}")
      nil
    end

    def pending?
      @mutex.synchronize { !@queue.empty? }
    end

    def ensure_worker
      return if @pid == Process.pid && @thread&.alive?

      @mutex.synchronize do
        next if @pid == Process.pid && @thread&.alive?
        @pid = Process.pid
        @queue = []
        @thread = Thread.new { run_loop }
        @thread.name = "watchtower-transport"
        @thread.report_on_exception = false
      end
    end

    def run_loop
      loop do
        item = @mutex.synchronize { @queue.shift }
        if item
          post(*item)
        else
          sleep 0.05
        end
      end
    rescue Exception => e # rubocop:disable Lint/RescueException
      Watchtower.log("worker died: #{e.class}: #{e.message}")
    end

    def post(kind, payload)
      uri = URI.parse("#{@config.url}/api/#{@config.public_key}/#{kind}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      if http.use_ssl?
        if @config.ca_file && File.readable?(@config.ca_file)
          http.ca_file = @config.ca_file
        elsif !@config.ssl_verify
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
      end
      http.open_timeout = @config.timeout
      http.read_timeout = @config.timeout
      req = Net::HTTP::Post.new(uri.request_uri, "content-type" => "application/json")
      req.body = JSON.generate(payload)
      http.request(req)
    rescue Exception => e # rubocop:disable Lint/RescueException
      Watchtower.log("post failed: #{e.class}: #{e.message}")
    end

    def install_at_exit
      at_exit { flush(timeout: 2.0) }
    rescue StandardError
      nil
    end

    def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
