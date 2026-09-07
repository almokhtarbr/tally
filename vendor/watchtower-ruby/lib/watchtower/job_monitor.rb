module Watchtower
  # Reports unhandled Active Job exceptions to /events. The performance
  # subscriber already records the failed *trace*; this surfaces the exception
  # itself in Issues, the way a request 500 shows up. Subscribes once, at
  # install; the `already_captured?` guard in Client keeps it from
  # double-reporting an error Rails.error also saw.
  module JobMonitor
    module_function

    def install!
      ActiveSupport::Notifications.subscribe("perform.active_job") do |_name, _start, _finish, _id, payload|
        report(payload)
      rescue StandardError
        nil
      end
    end

    def report(payload)
      ex = payload[:exception_object]
      return unless ex

      job = payload[:job]
      Watchtower.notify(ex, context: {
        mechanism: "active_job",
        job: {
          class:     (job.class.name rescue "ActiveJob"),
          id:        (job.job_id rescue nil),
          queue:     (job.queue_name rescue nil),
          arguments: safe_args(job),
          executions: (job.executions rescue nil)
        }.compact
      })
    end

    def safe_args(job)
      Array(job.arguments).map { |a| a.is_a?(String) ? a[0, 200] : a.class.name }
    rescue StandardError
      []
    end
  end
end
