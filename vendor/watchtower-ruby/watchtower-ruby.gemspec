require_relative "lib/watchtower/version"

Gem::Specification.new do |spec|
  spec.name        = "watchtower-ruby"
  spec.version     = Watchtower::VERSION
  spec.authors     = [ "Railyard" ]
  spec.summary     = "Ruby client for Watchtower — errors, performance, logs and metrics."
  spec.description = <<~TEXT
    Captures exceptions, transaction traces, logs and custom metrics and ships
    them to a Watchtower service over HTTP. Framework-agnostic core; the
    Railtie wires Rails up automatically when WATCHTOWER_URL and
    WATCHTOWER_PUBLIC_KEY are set. Every entry point is fail-safe — a
    Watchtower problem can never raise into, or slow down, the host app.
  TEXT
  spec.license  = "MIT"
  spec.homepage = "https://github.com/almokhtarbr/railyard"

  spec.required_ruby_version = ">= 3.2"
  spec.files = Dir["lib/**/*.rb", "lib/**/*.rake", "README.md"]
  spec.require_paths = [ "lib" ]

  spec.metadata["rubygems_mfa_required"] = "true"
end
