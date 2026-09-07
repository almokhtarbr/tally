require "rails/railtie"
require "watchtower"
require "watchtower/rack_middleware"
require "watchtower/error_subscriber"
require "watchtower/performance_subscriber"
require "watchtower/breadcrumbs"
require "watchtower/job_monitor"
require "watchtower/probe"

module Watchtower
  # Wires Watchtower into a Rails app. Loaded automatically by requiring the
  # gem; the host app only supplies configuration:
  #
  #   Watchtower.configure { |c| c.root = Rails.root.to_s }
  #
  # Everything below is a no-op unless WATCHTOWER_URL and
  # WATCHTOWER_PUBLIC_KEY are set (`Watchtower.enabled?`).
  class Railtie < ::Rails::Railtie
    initializer "watchtower.defaults", before: :load_config_initializers do |app|
      Watchtower.configure do |c|
        c.root   ||= ::Rails.root.to_s
        c.logger ||= ::Rails.logger
      end
    end

    initializer "watchtower.install", after: :load_config_initializers do |app|
      next unless Watchtower.enabled?

      app.config.middleware.insert_before(
        ActionDispatch::ShowExceptions, Watchtower::RackMiddleware
      )
      ::Rails.error.subscribe(Watchtower::ErrorSubscriber.new)

      # `initializer` blocks run against the Railtie instance; the helpers
      # below are class methods.
      Watchtower::Railtie.install_performance
      Watchtower::Railtie.install_log_forwarding
      Watchtower::Railtie.install_job_context
      Watchtower::Railtie.install_job_error_capture
      Watchtower::Railtie.install_breadcrumbs
      Watchtower::Railtie.install_rake_hook
      Watchtower::Railtie.install_action_cable_hook
      Watchtower::Railtie.install_probe
    end

    rake_tasks do
      load File.expand_path("tasks.rake", __dir__)
    end

    config.after_initialize do
      if Watchtower.enabled?
        ::Rails.logger.info "[watchtower] enabled -> #{Watchtower.config.url} (release #{Watchtower.config.release})"
      else
        ::Rails.logger.info "[watchtower] disabled (set WATCHTOWER_URL and WATCHTOWER_PUBLIC_KEY to enable)"
      end
    end

    class << self
      # Transaction traces (WATCHTOWER_PERF=0 to disable).
      def install_performance
        return unless Watchtower.config.perf_enabled

        Watchtower::PerformanceSubscriber.install!(Watchtower.config)
        return unless Watchtower.config.perf_instrument_http

        require "watchtower/http_instrumentation"
        Watchtower::HttpInstrumentation.install!
      end

      # Structured log forwarding (on by default; WATCHTOWER_CAPTURE_LOGS=0 off).
      def install_log_forwarding
        return unless Watchtower.config.capture_logs

        if ::Rails.logger.respond_to?(:broadcast_to)
          ::Rails.logger.broadcast_to(Watchtower.log_sink)
        else
          Watchtower.log("capture_logs on but Rails.logger has no #broadcast_to — logs not forwarded")
        end
      end

      # Every unhandled Active Job exception → an Issue.
      def install_job_error_capture
        return unless Watchtower.config.capture_job_errors

        Watchtower::JobMonitor.install!
      end

      # Minutely host/process probe.
      def install_probe
        return unless Watchtower.config.probe_enabled

        Watchtower::Probe.start(Watchtower.config)
      end

      def install_job_context
        ActiveSupport.on_load(:active_job) do
          around_perform do |job, block|
            Watchtower::Breadcrumbs.clear
            Watchtower::Breadcrumbs.add(category: "job", type: "info",
                                        message: "#{job.class.name} started",
                                        data: { queue: job.queue_name, id: job.job_id })
            Watchtower::Context.with(
              job: { class: job.class.name, id: job.job_id, queue: job.queue_name }
            ) { block.call }
          end
        end
      end

      def install_breadcrumbs
        ActiveSupport::Notifications.subscribe("start_processing.action_controller") do |*, payload|
          Watchtower::Breadcrumbs.clear
          Watchtower::Breadcrumbs.add(category: "request", type: "info",
                                      message: "#{payload[:method]} #{payload[:controller]}##{payload[:action]}",
                                      data: { path: payload[:path] })
        end

        ActiveSupport::Notifications.subscribe("sql.active_record") do |_n, start, finish, _id, payload|
          name = payload[:name].to_s
          next if name.blank? || name.start_with?("SCHEMA") || name == "TRANSACTION"

          Watchtower::Breadcrumbs.add(category: "query", type: "debug",
                                      message: payload[:sql].to_s.squish[0, 240],
                                      data: { name: name, ms: ((finish - start) * 1000).round(1) })
        end

        ActiveSupport::Notifications.subscribe("deliver.action_mailer") do |*, payload|
          Watchtower::Breadcrumbs.add(category: "mail", type: "info",
                                      message: "delivered #{payload[:mailer]}",
                                      data: { to: Array(payload[:to]).join(",") })
        end
      end

      # An error in a rake task (a recurring Solid Queue command, the release
      # `db:prepare`, a manual maintenance task) never touches the Rack or job
      # paths — report it here and re-raise so the task still fails.
      def install_rake_hook
        return unless defined?(Rake::Task)
        return unless File.basename($PROGRAM_NAME) == "rake" ||
                      ($0 && $0.include?("rake")) ||
                      defined?(::Rails::Command::RakeCommand)

        Rake::Task.prepend(RakeHook)
      end

      # subscribed / receive errors are logged and swallowed by ActionCable in
      # some paths; make sure they always reach Watchtower.
      def install_action_cable_hook
        ActiveSupport.on_load(:action_cable_channel) do
          rescue_from(StandardError) do |e|
            Watchtower.notify(e, context: { mechanism: "action_cable", channel: self.class.name })
            raise e
          end
        end
      end
    end

    module RakeHook
      def execute(*args)
        super
      rescue Exception => e # rubocop:disable Lint/RescueException
        begin
          Watchtower.notify(e, context: { mechanism: "rake", task: name })
        rescue StandardError
          nil
        end
        raise
      end
    end
  end
end
