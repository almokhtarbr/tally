# SDKs

Tally ships two SDKs. Both are designed to work inside other people's apps, so the #1 rule is: **never cause problems in the host app**.

---

## Ruby Gem — `tally_analytics`

### Design Constraints
- **Zero dependencies** — uses only Net::HTTP from Ruby stdlib. Analytics gems run inside Rails apps, Django apps, Sinatra apps. A dependency conflict between your gem and the host app is a production incident.
- **Fire and forget** — network errors are silently swallowed. A broken analytics service must never crash the host app.
- **Thread-safe** — single global client instance, safe for multi-threaded servers (Puma).

### Usage

```ruby
# config/initializers/tally.rb
TallyAnalytics.configure do |config|
  config.api_key = ENV["TALLY_API_KEY"]
  config.endpoint = "https://tally.example.com"
end

# Anywhere in your app
TallyAnalytics.track("user@email.com", "subscription-update", plan: "premium", mrr: 99)
TallyAnalytics.identify("user@email.com", name: "Jane Doe", plan: "premium")
TallyAnalytics.alias("anon_abc123", "user@email.com")
```

### Replacing Mixpanel in C-Cube (Vroom)

| Before (Mixpanel) | After (Tally) |
|---|---|
| `tracker.track(email, "new-user")` | `TallyAnalytics.track(email, "new-user")` |
| `tracker.track(email, "subscription-update")` | `TallyAnalytics.track(email, "subscription-update")` |
| `tracker.people.set(email, {...})` | `TallyAnalytics.identify(email, {...})` |

~5 call sites on the backend. 10-minute swap.

---

## JavaScript SDK — `tally.js`

### Design Constraints
- **~2KB minified** — loaded on every page, must be tiny
- **Client-side batching** — accumulate events in memory, flush every 5 seconds. Reduces HTTP requests from N to 1.
- **sendBeacon on unload** — `navigator.sendBeacon` fires reliably on page close. Without this, 10-30% of events are lost on navigation.
- **localStorage for identity** — generates `anon_xxxx` UUID, stored in localStorage (no cookies = simpler privacy/GDPR)
- **No dependencies** — vanilla JS, no build step required for the host app

### Usage

```html
<!-- Drop this in your app's <head> -->
<script src="https://tally.example.com/sdk/tally.js"></script>
<script>
  tally('init', 'pk_abc123');
  tally('track', 'page-view', { page: '/quotes' });
  tally('identify', 'user@email.com', { plan: 'premium' });
</script>
```

### How batching works

```
Event fired → pushed to in-memory queue
                 ↓
            5-second timer fires (or page unload)
                 ↓
            POST /api/v1/batch with all queued events
                 ↓
            Queue cleared on success, re-queued on failure
```

### Replacing Intercom tracking in C-Cube (Vroom frontend)

| Before (Intercom) | After (Tally) |
|---|---|
| `intercom.trackEvent("quote")` | `tally('track', 'quote')` |
| `intercom.trackEvent("project")` | `tally('track', 'project')` |

~5 call sites on the frontend. Another 10-minute swap.

---

## SDK Design Decisions Worth Discussing

1. **Why zero dependencies?** — Error/analytics gems run inside other apps. A version conflict between your `faraday` and the host app's `faraday` is a production incident that has nothing to do with analytics.

2. **Why swallow errors silently?** — Analytics is never on the critical path. If Tally is down, the host app must keep working. Log a warning, move on.

3. **Why sendBeacon?** — Regular XHR/fetch requests get cancelled on page navigation. `sendBeacon` is specifically designed to survive page unloads. Without it, you lose every event that happens right before a user navigates away.

4. **Why localStorage over cookies?** — Simpler privacy story. No cookie banners needed for a UUID that never leaves the analytics context. Cookies also get sent on every HTTP request to the domain, which is wasteful.
