require "net/http"

module Watchtower
  # Records outbound Net::HTTP calls as `http` spans on the current
  # transaction trace. Every APM agent (AppSignal, Scout, Datadog) does
  # this with a targeted wrapper — it is the one place Watchtower prepends
  # a stdlib method, gated by `config.perf_instrument_http` (default on)
  # and only installed alongside the performance subscriber.
  #
  # Fail-safe: the wrapper only times the call and records a span; any
  # error in the instrumentation is swallowed and the real request result
  # (or its exception) is passed straight through.
  module HttpInstrumentation
    def self.install!
      return if @installed
      @installed = true
      Net::HTTP.prepend(NetHttp)
    end

    module NetHttp
      def request(req, body = nil, &block)
        return super unless started?

        t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        begin
          super
        ensure
          begin
            t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            meth = (req.respond_to?(:method) ? req.method : "GET").to_s
            path = req.respond_to?(:path) ? req.path.to_s.split("?", 2).first : nil
            Watchtower::PerformanceSubscriber.add_span(
              :http, "#{meth} #{address}", t0, t1, detail: path
            )
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
