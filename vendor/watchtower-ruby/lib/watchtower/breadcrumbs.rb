module Watchtower
  # A per-thread ring buffer of the events leading up to an error — SQL,
  # controller actions, jobs, outbound HTTP, and anything the app records with
  # Watchtower.log_breadcrumb. Attached to each reported event.
  module Breadcrumbs
    KEY = :watchtower_breadcrumbs
    MAX = 30

    module_function

    def buffer
      Thread.current[KEY] ||= []
    end

    def add(message:, category: "custom", type: "default", data: nil)
      b = buffer
      b << {
        type: type,
        category: category,
        message: message.to_s[0, 400],
        timestamp: Time.now.utc.iso8601(3),
        data: data.is_a?(Hash) ? data.transform_values { |v| v.to_s[0, 200] } : nil,
      }.compact
      b.shift while b.length > MAX
      nil
    rescue StandardError
      nil
    end

    def to_a
      buffer.dup
    end

    def clear
      Thread.current[KEY] = []
    end
  end
end
