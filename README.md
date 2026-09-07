# Tally

A self-hosted product analytics service. Track events, identify users, and visualize trends — without paying $1000+/month for Mixpanel or Amplitude.

Built for SaaS apps that only need the 20% of analytics features that matter: event tracking, funnels, retention, and a dashboard.

## Features

- **Event Tracking** — Track custom events with flexible JSONB properties
- **User Identification** — Identify users, merge anonymous sessions, track user journeys
- **Funnels** — Multi-step conversion funnels with time windows and property filters
- **Retention** — Weekly/daily cohort retention grids with segment filtering
- **Real-time Dashboard** — Live event feed, KPI cards, charts (Hotwire Turbo)
- **Error Tracking** — JS errors, promise rejections, server errors with business impact analysis
- **Form Analytics** — Field-level drop-off funnels, time-per-field heatmaps
- **User Paths** — Session flow analysis and navigation patterns
- **Anomaly Detection** — Z-score based spike/drop alerts with webhook notifications
- **Segments** — Behavioral + property-based user cohorts
- **Webhooks** — HMAC-signed HTTP webhooks with event filtering and auto-disable
- **CSV Export** — Export events, users, funnels, and retention data
- **Multi-SDK Support** — Ruby, JavaScript, Python, Node.js, and Go SDKs (all zero-dependency)

## Tech Stack

- **Backend:** Rails 8, PostgreSQL, Solid Queue
- **Frontend:** Hotwire (Turbo + Stimulus), Tailwind CSS, Chart.js
- **Deploy:** Kamal 2 + Thruster
- **Auth:** `has_secure_password` with role-based access (admin/member, owner/editor/viewer)

## Architecture Highlights

- **Partitioned events table** — Monthly partitions for partition pruning and faster vacuuming. Set `EVENTS_RETENTION_MONTHS` and `DropExpiredPartitionsJob` drops whole aged-out partitions nightly — O(1) retention, no row scan
- **Pre-aggregated rollups** — `EventDailyRollup` table for O(1) dashboard reads via atomic upserts
- **Identity resolution** — Anonymous-to-identified user merging via background jobs
- **Rate limiting** — Rack::Attack throttling on write and read endpoints
- **Idempotency** — Partial unique index on `(project_id, idempotency_key, occurred_at)` for safe retries
- **Zero-dependency SDKs** — All SDKs use only stdlib (no gem/package conflicts with host apps)

## API

**Write endpoints** (authenticated via `X-API-Key` header):
- `POST /api/v1/track` — Track an event
- `POST /api/v1/batch` — Batch track events
- `POST /api/v1/identify` — Identify a user
- `POST /api/v1/alias` — Link anonymous ID to user

**Read endpoints** (authenticated via `Bearer` token):
- `GET /api/v1/queries/event_counts` — Event counts over time
- `GET /api/v1/queries/top_events` — Top events by count
- `GET /api/v1/queries/user_timeline` — User event timeline

## Getting Started

```bash
git clone https://github.com/almokhtarbr/tally.git
cd tally
bin/setup
bin/dev
```

Seed demo data:
```bash
bin/rails db:seed
```

Visit `http://localhost:3000` and follow the setup wizard.

## SDK Usage

**Ruby:**
```ruby
TallyAnalytics.configure do |c|
  c.api_key = "pk_your_key"
  c.endpoint = "https://tally.yourdomain.com"
end

TallyAnalytics.track("user@example.com", "purchase", plan: "pro", amount: 99)
```

**JavaScript:**
```html
<script src="https://tally.yourdomain.com/sdk/tally.js"></script>
<script>
  tally('init', 'pk_your_key', { endpoint: 'https://tally.yourdomain.com' });
  tally('track', 'button_clicked', { page: '/pricing' });
</script>
```

## Testing

```bash
bundle exec rspec
```

82 specs covering models, services, jobs, and API endpoints.

## Deployment

Configured for Kamal 2. Update `config/deploy.yml` with your server details and run:

```bash
bin/kamal setup
```

## Documentation

See the `docs/` directory for detailed documentation:

- [Architecture](docs/ARCHITECTURE.md) — System design and scaling considerations
- [API Reference](docs/API.md) — Full API documentation
- [SDK Guide](docs/SDKS.md) — SDK integration details
- [Implementation](docs/IMPLEMENTATION.md) — Build order and design decisions

## License

MIT
