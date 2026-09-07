module Watchtower
  # Buffers application metrics (counter / gauge / distribution) into
  # per-minute buckets and flushes them to Watchtower's /custom_metrics
  # ingest on an interval. Thread-safe, fork-safe, never blocks the caller,
  # never raises out.
  #
  #   Watchtower.increment("orders.placed", tags: { plan: "pro" })
  #   Watchtower.gauge("queue.depth", SolidQueue::Job.pending.count)
  #   Watchtower.measure("checkout.ms", 812.4)
  #   Watchtower.time("checkout.ms") { run_checkout }
  class CustomMetrics
    FLUSH_INTERVAL = 30
    MAX_KEYS = 5_000

    def initialize(config)
      @config = config
      @mutex  = Mutex.new
      @buf    = {}
      @pid    = nil
      @thread = nil
    end

    def increment(name, by: 1, tags: {}) = record(name, "counter", by.to_f, tags)
    def gauge(name, value, tags: {})     = record(name, "gauge", value.to_f, tags)
    def measure(name, value, tags: {})   = record(name, "distribution", value.to_f, tags)

    def time(name, tags: {})
      t0 = monotonic
      yield
    ensure
      measure(name, (monotonic - t0) * 1000.0, tags: tags)
    end

    def flush!
      batch = nil
      @mutex.synchronize do
        batch = @buf.values
        @buf = {}
      end
      return if batch.empty?

      Watchtower.client.transport.deliver_custom_metrics(metrics: batch.map { |m| serialize(m) })
    rescue Exception => e # rubocop:disable Lint/RescueException
      Watchtower.log("custom_metrics flush: #{e.class}: #{e.message}")
    end

    private

    def record(name, kind, value, tags)
      return unless Watchtower.enabled?
      ensure_worker
      minute = (Time.now.to_i / 60) * 60
      key = [ name, kind, tags, minute ]
      @mutex.synchronize do
        return if @buf.size >= MAX_KEYS && !@buf.key?(key)
        m = @buf[key] ||= {
          name: name, kind: kind, tags: tags,
          at: Time.at(minute).utc.iso8601,
          count: 0, sum: 0.0, min: nil, max: nil, last: nil
        }
        m[:count] += 1
        m[:sum]   += value
        m[:min]    = [ m[:min], value ].compact.min
        m[:max]    = [ m[:max], value ].compact.max
        m[:last]   = value
      end
      nil
    rescue Exception => e # rubocop:disable Lint/RescueException
      Watchtower.log("custom_metrics record: #{e.class}: #{e.message}")
      nil
    end

    def serialize(m)
      { name: m[:name], kind: m[:kind], tags: m[:tags], at: m[:at],
        count: m[:count], sum: m[:sum].round(4), min: m[:min], max: m[:max], last: m[:last] }
    end

    def ensure_worker
      return if @pid == Process.pid && @thread&.alive?
      @mutex.synchronize do
        next if @pid == Process.pid && @thread&.alive?
        @pid = Process.pid
        @buf = {}
        @thread = Thread.new { run_loop }
        @thread.name = "watchtower-custom-metrics"
        @thread.report_on_exception = false
        @at_exit_installed ||= (at_exit { flush! } || true)
      end
    end

    def run_loop
      loop do
        sleep FLUSH_INTERVAL
        flush!
      end
    rescue Exception => e # rubocop:disable Lint/RescueException
      Watchtower.log("custom_metrics worker died: #{e.class}: #{e.message}")
    end

    def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
