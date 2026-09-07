require "socket"
require "time"

module Watchtower
  # Turns Rails' ActiveSupport::Notifications stream into transaction traces
  # and ships the slow ones to Watchtower's /transactions ingest.
  #
  # One parent event (`process_action.action_controller` for web,
  # `perform.active_job` for background) bounds a trace; child events
  # (`sql.active_record`, view renders, cache) become spans. A trace is
  # shipped when its wall time crosses `perf_slow_threshold_ms`, or by the
  # `perf_sample_rate` dice roll. Everything runs on the request thread, so
  # the span buffer is a plain thread-local; delivery is async via Transport.
  #
  # Fail-safe: every subscriber block body is wrapped — a bug in here can
  # never raise into a controller action or a job.
  class PerformanceSubscriber
    CHILD_EVENTS = {
      "sql.active_record"             => :db,
      "render_template.action_view"   => :view,
      "render_partial.action_view"    => :view,
      "render_collection.action_view" => :view,
      "render_layout.action_view"     => :view,
      "cache_read.active_support"     => :cache,
      "cache_write.active_support"    => :cache,
      "cache_delete.active_support"   => :cache
    }.freeze

    BUFFER_KEY  = :watchtower_perf_spans
    MAX_BUFFER  = 5_000
    SKIP_SQL    = /\A(SCHEMA|TRANSACTION|EXPLAIN)/i

    def self.install!(config)
      new(config).install!
    end

    # Append a span to the current trace's buffer, if a trace is in progress
    # on this thread. For external instrumenters (HTTP, etc). `start` /
    # `finish` are monotonic seconds. Never raises.
    def self.add_span(category, name, start, finish, detail: nil, n: 1)
      buf = Thread.current[BUFFER_KEY]
      return unless buf.is_a?(Array) && buf.size < MAX_BUFFER
      buf << { category: category.to_sym, name: name.to_s[0, 200],
               detail: detail&.to_s&.slice(0, 500), n: n,
               start: start, finish: finish }
    rescue StandardError
      nil
    end

    def initialize(config)
      @config = config
      @host   = (Socket.gethostname rescue nil)
    end

    def install!
      CHILD_EVENTS.each do |name, category|
        ActiveSupport::Notifications.monotonic_subscribe(name) do |ename, start, finish, _id, payload|
          safe { record_span(category, ename, start, finish, payload) }
        end
      end

      ActiveSupport::Notifications.monotonic_subscribe("process_action.action_controller") do |_n, start, finish, _id, payload|
        safe do
          action = "#{payload[:controller]}##{payload[:action]}"
          finish_transaction("web", action, start, finish,
                             request_id: (payload[:request]&.request_id rescue nil),
                             status: payload[:status])
        end
      end

      ActiveSupport::Notifications.monotonic_subscribe("perform.active_job") do |_n, start, finish, _id, payload|
        safe do
          job = payload[:job]
          name = job.respond_to?(:class) ? job.class.name : "ActiveJob"
          errored = payload[:exception_object] || payload[:exception] || payload[:aborted]
          finish_transaction("background", name, start, finish, request_id: nil,
                             queue_ms: queue_ms_for(job, start, finish), error: !errored.nil?)
        end
      end

      self
    end

    private

    def buffer
      Thread.current[BUFFER_KEY] ||= []
    end

    def reset
      Thread.current[BUFFER_KEY] = []
    end

    def record_span(category, ename, start, finish, payload)
      buf = buffer
      return if buf.size >= MAX_BUFFER

      name, detail, n = describe(category, ename, payload)
      return if name.nil?

      buf << { category: category, name: name, detail: detail, n: n, start: start, finish: finish }
    end

    def describe(category, ename, payload)
      case ename
      when "sql.active_record"
        sql = payload[:sql].to_s
        nm  = payload[:name].to_s
        return nil if sql.empty? || nm =~ SKIP_SQL || nm == "SCHEMA"
        [ (nm.empty? ? "SQL" : nm), sql.dup, 1 ]
      when "render_collection.action_view"
        [ "render collection", rel_path(payload[:identifier]), payload[:count].to_i.clamp(1, 100_000) ]
      when /\Arender_/
        [ "render", rel_path(payload[:identifier]), 1 ]
      when /\Acache_/
        [ ename.split(".").first.tr("_", " "), payload[:key].to_s[0, 120].presence, 1 ]
      else
        [ ename, nil, 1 ]
      end
    end

    def rel_path(identifier)
      s = identifier.to_s
      return nil if s.empty?
      root = @config.root.to_s
      s.start_with?(root) ? s[(root.length + 1)..] : s.split("/").last(3).join("/")
    end

    # Approximate time a job waited in the queue: (now − enqueued_at) minus
    # its run time. `job.enqueued_at` is an ISO8601 string on ActiveJob
    # (Rails 7.1+); nil for jobs run inline / not through a queue.
    def queue_ms_for(job, start, finish)
      raw = (job.respond_to?(:enqueued_at) && job.enqueued_at) || nil
      return nil if raw.nil?

      enq = raw.is_a?(Time) ? raw : Time.parse(raw.to_s)
      run_ms = (finish - start) * 1000.0
      waited = ((Time.now.utc - enq.utc) * 1000.0) - run_ms
      waited.clamp(0, 3_600_000).round(1)
    rescue StandardError
      nil
    end

    def finish_transaction(namespace, action, start, finish, request_id:, status: nil, queue_ms: nil, error: false)
      buf = buffer
      reset
      return if action.to_s.empty? || action.end_with?("#")

      wall_ms = ((finish - start) * 1000.0).round
      return unless error || capture?(wall_ms)

      spans = buf.select { |s| s[:start] >= start - 0.0005 && s[:finish] <= finish + 0.05 }
                 .sort_by { |s| s[:start] }
      spans = trim(spans)

      payload = {
        action:      action,
        namespace:   namespace,
        duration_ms: wall_ms,
        timestamp:   Time.now.utc.iso8601,
        environment: @config.environment,
        release:     @config.release,
        server_name: @host,
        request_id:  request_id,
        spans: spans.map do |s|
          {
            name:        s[:name],
            category:    s[:category],
            start_ms:    ((s[:start] - start) * 1000.0).round(2),
            duration_ms: ((s[:finish] - s[:start]) * 1000.0).round(2),
            detail:      s[:detail],
            n:           s[:n]
          }.compact
        end
      }
      payload[:context]  = { status: status } if status
      payload[:queue_ms] = queue_ms if queue_ms
      payload[:error]    = true if error

      Watchtower.client.transport.deliver_transaction(payload)
    end

    def capture?(wall_ms)
      return true if wall_ms >= @config.perf_slow_threshold_ms
      r = @config.perf_sample_rate.to_f
      r > 0 && rand < r
    end

    # Keep the trace legible: if over the span cap, keep the longest ones.
    def trim(spans)
      max = @config.perf_max_spans
      return spans if spans.size <= max
      spans.sort_by { |s| -(s[:finish] - s[:start]) }.first(max).sort_by { |s| s[:start] }
    end

    def safe
      yield
    rescue Exception => e # rubocop:disable Lint/RescueException
      Watchtower.log("perf subscriber: #{e.class}: #{e.message}")
      nil
    end
  end
end
