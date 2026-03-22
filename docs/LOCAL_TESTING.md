# Local Testing Guide

How to test Tally with Vroom (C-Cube) locally.

---

## 1. Start both servers

**Terminal 1 — Tally** (port 3001):
```bash
cd /Users/al/Developer.nosync/tally
bin/rails server -p 3001
```

**Terminal 2 — Vroom** (port 3000):
```bash
cd /Users/al/Developer.nosync/vroom
bin/rails server -p 3000
```

---

## 2. Create a project in Tally

1. Go to `http://localhost:3001` (login: `admin` / `tally`)
2. Click "New Project"
3. Name: `C-Cube`, URL: `http://localhost:3000`
4. Go to "API Keys" — copy the `pk_xxx` key

---

## 3. Test from Vroom's Rails console

```ruby
require '/Users/al/Developer.nosync/tally/lib/tally_analytics'

TallyAnalytics.configure do |c|
  c.api_key = "pk_xxx"  # paste your key
  c.endpoint = "http://localhost:3001"
end

# Track an event
TallyAnalytics.track("you@email.com", "subscription-update", plan: "premium")

# Identify a user
TallyAnalytics.identify("you@email.com", name: "Your Name", plan: "premium", tenant: "acme")

# Batch test
5.times { |i| TallyAnalytics.track("you@email.com", "test-event-#{i}") }
```

Then refresh `http://localhost:3001/projects/1` to see events appear.

---

## 4. Test with curl (no Vroom needed)

```bash
# Track
curl -X POST http://localhost:3001/api/v1/track \
  -H "X-API-Key: pk_xxx" \
  -H "Content-Type: application/json" \
  -d '{"event":"test","user_id":"me@test.com"}'

# Batch
curl -X POST http://localhost:3001/api/v1/batch \
  -H "X-API-Key: pk_xxx" \
  -H "Content-Type: application/json" \
  -d '{"events":[{"event":"a","user_id":"me@test.com"},{"event":"b","user_id":"me@test.com"}]}'

# Identify
curl -X POST http://localhost:3001/api/v1/identify \
  -H "X-API-Key: pk_xxx" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"me@test.com","properties":{"plan":"premium"}}'

# Query (use sk_ secret key)
curl "http://localhost:3001/api/v1/queries/top_events?from=2026-03-01&to=2026-03-31" \
  -H "Authorization: Bearer sk_xxx"
```

---

## 5. Test JS SDK in browser

Open any HTML page (or Vroom's frontend) and add:

```html
<script src="http://localhost:3001/sdk/tally.js"></script>
<script>
  tally('init', 'pk_xxx', { endpoint: 'http://localhost:3001' });
  tally('track', 'page-view', { page: window.location.pathname });
</script>
```

Events batch every 5 seconds and flush on page close via `sendBeacon`.

---

## 6. Wire into Vroom for real (when ready)

### Backend — replace Mixpanel calls

Add to Vroom's `config/initializers/tally.rb`:
```ruby
require '/Users/al/Developer.nosync/tally/lib/tally_analytics'

TallyAnalytics.configure do |c|
  c.api_key = ENV.fetch("TALLY_API_KEY", "pk_xxx")
  c.endpoint = ENV.fetch("TALLY_ENDPOINT", "http://localhost:3001")
end
```

Then replace in Vroom's code:

| File | Before | After |
|---|---|---|
| `subscriptions_controller.rb:20-21` | `Mixpanel::Tracker.new(token).track(email, "subscription-update")` | `TallyAnalytics.track(email, "subscription-update")` |
| `subscriptions_controller.rb:49-50` | `tracker.track(email, "subscription-verified")` | `TallyAnalytics.track(email, "subscription-verified")` |
| `api/tenants_controller.rb:46` | `@tracker.track(email, "free-start/end")` | `TallyAnalytics.track(email, "free-#{@tenant.free ? 'start' : 'end'}")` |
| `api/tenants_controller.rb:68` | `@tracker.track(email, "active-start/end")` | `TallyAnalytics.track(email, "active-#{@tenant.active ? 'start' : 'end'}")` |
| `api/tenants_controller.rb:87` | `@tracker.track(email, "trial-ended")` | `TallyAnalytics.track(email, "trial-ended")` |
| `update_analytics_user_listener.rb:9` | `tracker.people.set(email, {...})` | `TallyAnalytics.identify(email, ...)` |
| `update_analytics_user_listener.rb:18` | `tracker.track(email, "new-user")` | `TallyAnalytics.track(email, "new-user")` |

### Frontend — replace Intercom tracking

In Vroom's Ember `index.html`:
```html
<script src="http://localhost:3001/sdk/tally.js"></script>
<script>
  tally('init', 'pk_xxx', { endpoint: 'http://localhost:3001' });
</script>
```

Then in Ember controllers, replace `intercom.trackEvent("quote")` with `window.tally('track', 'quote')`.

---

## Troubleshooting

- **Events not showing?** Check Tally server logs in terminal 1 for errors.
- **CORS errors in browser?** Tally needs CORS config for cross-origin JS SDK calls — see `config/initializers/cors.rb`.
- **Login prompt?** Dashboard uses HTTP Basic Auth: `admin` / `tally` (set via `ADMIN_USER` / `ADMIN_PASSWORD` env vars).
