module Watchtower
  # Per-thread bag of request / job / user data folded into each event.
  module Context
    KEY = :watchtower_context

    class << self
      def store
        Thread.current[KEY] ||= { request: nil, job: nil, user: nil, tags: {} }
      end

      def []=(key, value)
        store[key] = value
      end

      def [](key)
        store[key]
      end

      def to_h
        store.dup
      end

      def clear
        Thread.current[KEY] = nil
      end

      # Run a block with extra context merged in, restoring the prior state.
      def with(**attrs)
        prior = store.dup
        attrs.each { |k, v| store[k] = v }
        yield
      ensure
        Thread.current[KEY] = prior
      end
    end
  end
end
