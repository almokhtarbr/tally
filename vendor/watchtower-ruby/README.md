# watchtower-ruby

Ruby client for [Watchtower](../../..) — error tracking, performance
tracing, log forwarding and custom metrics.

```ruby
gem "watchtower-ruby", path: "vendor/watchtower-ruby"
```

With `WATCHTOWER_URL` and `WATCHTOWER_PUBLIC_KEY` set, the Railtie wires
everything up: Rack middleware, `Rails.error` subscriber, Active Job
context, breadcrumbs, the performance subscriber, rake and ActionCable
hooks. Without them every entry point is a no-op.

```ruby
Watchtower.notify(e, context: { mechanism: "manual" })
Watchtower.increment("signups")
Watchtower.measure("import.ms") { do_import }
```

Extracted from `railyard/lib/watchtower` so the two Railyard clones stop
drifting. Still vendored by path; lift it to its own repo when a third
app needs it.
