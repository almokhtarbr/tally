# Watchtower client configuration. The library is the vendored `watchtower-ruby`
# gem (vendor/watchtower-ruby) — the same client Railyard runs. Its Railtie
# installs the Rack middleware, the Rails.error subscriber, Active Job context,
# breadcrumbs, the performance subscriber and the rake / ActionCable hooks.
#
# Everything is a no-op until BOTH the URL and WATCHTOWER_PUBLIC_KEY resolve.
# Railyard injects WATCHTOWER_URL + WATCHTOWER_PUBLIC_KEY into the deploy env.
Watchtower.configure do |c|
  c.root   = Rails.root.to_s
  c.logger = Rails.logger
  c.url  ||= ENV["WATCHTOWER_URL"].presence
end
