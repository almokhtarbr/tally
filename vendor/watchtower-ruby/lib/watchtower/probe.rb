module Watchtower
  # A minutely background probe: process memory, GC, threads, open files, DB
  # connection pool, and system load — the "host metrics" panel. Ships each
  # sample through Watchtower.gauge (custom metrics). One daemon thread,
  # recreated after a fork. Every read is guarded; a probe failure is silent.
  class Probe
    def self.start(config)
      new(config).start
    end

    def initialize(config)
      @config   = config
      @interval = [ config.probe_interval.to_i, 10 ].max
      @pid      = nil
      @thread   = nil
      @mutex    = Mutex.new
    end

    def start
      ensure_thread
      self
    end

    private

    def ensure_thread
      return if @pid == Process.pid && @thread&.alive?

      @mutex.synchronize do
        return if @pid == Process.pid && @thread&.alive?

        @pid = Process.pid
        @thread = Thread.new do
          loop do
            sleep @interval
            sample
          rescue StandardError
            nil
          end
        end
        @thread.name = "watchtower-probe"
        @thread.report_on_exception = false
      end
    end

    def sample
      return unless Watchtower.enabled?

      gauge("process.memory_mb", rss_mb)
      gauge("process.threads", Thread.list.count)
      gauge("process.open_fds", open_fds)

      gc = GC.stat
      gauge("process.gc.count", gc[:count])
      gauge("process.gc.major_count", gc[:major_gc_count])
      gauge("process.gc.heap_live_slots", gc[:heap_live_slots])
      gauge("process.gc.old_objects", gc[:old_objects])

      pool = ar_pool_stat
      if pool
        gauge("db.pool.size", pool[:size])
        gauge("db.pool.busy", pool[:busy])
        gauge("db.pool.idle", pool[:idle])
        gauge("db.pool.waiting", pool[:waiting])
      end

      la = load_average
      gauge("system.load.1m", la) if la
    end

    def gauge(name, value)
      return if value.nil?

      Watchtower.gauge(name, value.to_f)
    rescue StandardError
      nil
    end

    def rss_mb
      if File.readable?("/proc/self/status")
        line = File.foreach("/proc/self/status").find { |l| l.start_with?("VmRSS:") }
        return line.split[1].to_f / 1024.0 if line
      end
      kb = `ps -o rss= -p #{Process.pid}`.to_i
      kb.positive? ? kb / 1024.0 : nil
    rescue StandardError
      nil
    end

    def open_fds
      Dir.children("/proc/self/fd").count
    rescue StandardError
      nil
    end

    def load_average
      File.read("/proc/loadavg").split.first.to_f
    rescue StandardError
      nil
    end

    def ar_pool_stat
      return nil unless defined?(::ActiveRecord::Base)

      stat = ::ActiveRecord::Base.connection_pool.stat
      { size: stat[:size], busy: stat[:busy], idle: stat[:idle], waiting: stat[:waiting] }
    rescue StandardError
      nil
    end
  end
end
