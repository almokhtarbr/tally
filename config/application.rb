require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module Tally
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])
    config.active_record.schema_format = :sql

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins "*"
        resource "/api/v1/*", headers: :any, methods: [ :post, :get, :options ], credentials: false
        resource "/sdk/*", headers: :any, methods: [ :get ], credentials: false
      end
    end
  end
end
