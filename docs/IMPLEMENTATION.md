# Implementation Guide

This document explains **what** we're building, **how** we're building it, and most importantly **why** every decision was made. Written so you can revisit this in 6 months and understand the reasoning.

---

## Tech Stack Decisions

### Why Rails 8 (not Go, not Node, not Django)

- **You ship faster in Rails.** A portfolio project that's done in 4 weeks beats a "better" one half-finished in Go.
- **Rails 8 is batteries-included.** Background jobs (Solid Queue), caching (Solid Cache), WebSockets (Solid Cable), deployment (Kamal), reverse proxy (Thruster) — all built in. Zero external dependencies to configure.
- **Full-stack in one framework.** We need both a JSON API (for SDKs to hit) and an HTML dashboard (for humans). Rails serves both without stitching together separate services.
- **At our scale (<1K events/day), performance is irrelevant.** A single INSERT takes <5ms. Rails handles this without breaking a sweat. If we hit 100K/day, we extract the ingestion endpoint to Go — that's a scaling story, not a day-1 problem.

### Why PostgreSQL (not MySQL, not MongoDB, not ClickHouse)

- **JSONB** — Event properties are schema-free. JSONB gives us flexibility without losing queryability. GIN indexes let us query inside JSON efficiently.
- **Native partitioning** — Monthly partitions on the events table. Time-range queries only scan relevant partitions. Data retention is `DROP PARTITION` (O(1)) instead of `DELETE WHERE` (O(n) + bloat).
- **Battle-tested for analytics at this scale.** ClickHouse is better for 100M+ events, but it's a separate infrastructure to manage. PostgreSQL does everything we need in one database.
- **Rails' default.** Less configuration, fewer surprises.

### Why Kamal 2 (not Render, not Heroku, not manual Docker)

- **DHH's way.** Kamal ships with Rails 8 by default. It's the intended deployment path.
- **Zero-downtime deploys** out of the box with rolling restarts.
- **Thruster** sits in front of Puma — handles HTTP/2, asset caching, gzip compression. No Nginx config to maintain.
- **Any VPS works.** Not locked into a PaaS. A $5/mo server runs this fine.
- **Portfolio signal.** Shows you understand deployment, not just development.

### Why Solid Queue (not Sidekiq, not Redis-backed anything)

- **Ships with Rails 8.** No gem to add, no Redis to run.
- **Database-backed.** Uses the same PostgreSQL instance. One less service to deploy and monitor.
- **Good enough.** We have 2 background jobs (identity resolution + partition maintenance). We don't need Sidekiq's throughput.
- **Trade-off acknowledged:** At 10K+ jobs/day, Sidekiq + Redis would be faster. But we're at <100/day.

### Why Hotwire/Turbo (not React, not a SPA)

- **The dashboard is read-heavy with simple interactions.** Date picker, table sorting, chart rendering — that's it. No complex state management needed.
- **Turbo Frames** give us lazy-loading and partial page updates without shipping a JS framework.
- **Portfolio signal.** The host app (C-Cube) is Ember. This is server-rendered Rails. Shows range — different tools for different problems.
- **No build step.** No webpack, no node_modules, no JS bundler to configure.

### Why Tailwind CSS

- **Fast to prototype.** Utility classes mean you don't write CSS files or name things.
- **Ships with Rails 8** via Propshaft. Zero config.
- **Good enough for a dashboard.** We're not building a design system.

---

## Database Schema — The Schema IS the System Design

### Why 5 tables (not 3, not 10)

Each table has a single responsibility. No table serves two masters.

```
projects              → "Who is sending me data?"
user_profiles         → "Who are the users in each app?"
events                → "What happened?" (the core data)
event_daily_rollups   → "Pre-computed answers for the dashboard"
identity_aliases      → "How do anonymous users become known?"
```

### Table: `projects`

```sql
CREATE TABLE projects (
  id            bigserial PRIMARY KEY,
  name          varchar NOT NULL,
  url           varchar,
  api_key       varchar NOT NULL,  -- prefixed pk_, public, write-only
  api_secret    varchar NOT NULL,  -- prefixed sk_, private, read-only
  events_count  integer DEFAULT 0, -- counter cache for quick stats
  created_at    timestamp NOT NULL,
  updated_at    timestamp NOT NULL
);

CREATE UNIQUE INDEX idx_projects_api_key ON projects (api_key);
CREATE UNIQUE INDEX idx_projects_api_secret ON projects (api_secret);
```

**Why two keys?**
- The API key (`pk_`) is embedded in client-side JavaScript. It's public. It can only WRITE events. If someone reads your page source and finds it, they can only send you junk events — they can't read your data.
- The API secret (`sk_`) is used server-side to READ data (query endpoints). It never leaves your backend.
- This is how Mixpanel, Amplitude, PostHog, and Stripe all do it. Industry standard pattern.

**Why `pk_` / `sk_` prefixes?**
- Stripe popularized this. When you see `pk_abc123` in a config file, you immediately know it's a public key. When you see `sk_abc123`, you know it's secret. Reduces mistakes.
- Also helps with secret scanning tools (GitHub, GitGuardian) — they can pattern-match on the prefix.

### Table: `user_profiles`

```sql
CREATE TABLE user_profiles (
  id            bigserial PRIMARY KEY,
  project_id    bigint NOT NULL REFERENCES projects(id),
  external_id   varchar NOT NULL,  -- the host app's user identifier (email, UUID, etc.)
  properties    jsonb DEFAULT '{}',
  first_seen_at timestamp,
  last_seen_at  timestamp,
  created_at    timestamp NOT NULL,
  updated_at    timestamp NOT NULL
);

CREATE UNIQUE INDEX idx_user_profiles_project_external ON user_profiles (project_id, external_id);
```

**Why `external_id` instead of `email`?**
- Different apps identify users differently — email, UUID, username, database ID. We don't make assumptions. The host app decides what their user identifier is.
- This is how Mixpanel (`distinct_id`), Amplitude (`user_id`), and PostHog (`distinct_id`) all do it.

**Why JSONB for properties?**
- Different apps track different user properties. C-Cube might track `{ plan: "premium", tenant: "acme" }`. Another app might track `{ role: "admin", department: "engineering" }`.
- No migrations needed when an app adds a property. Just send it.
- GIN-indexable if we ever need to query by property value.

**Why `first_seen_at` / `last_seen_at`?**
- "When did this user first appear?" and "When were they last active?" are the two most common user-level questions. Pre-computing these avoids scanning the entire events table.

### Table: `events` (partitioned)

```sql
CREATE TABLE events (
  id               bigserial,
  project_id       bigint NOT NULL,
  user_profile_id  bigint,          -- nullable: anonymous events exist
  name             varchar NOT NULL,
  properties       jsonb DEFAULT '{}',
  idempotency_key  varchar,
  occurred_at      timestamp NOT NULL,
  created_at       timestamp NOT NULL,
  PRIMARY KEY (id, occurred_at)     -- partition key must be in PK
) PARTITION BY RANGE (occurred_at);

-- Create monthly partitions
CREATE TABLE events_2026_03 PARTITION OF events
  FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE events_2026_04 PARTITION OF events
  FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

-- Indexes (created on each partition automatically)
CREATE INDEX idx_events_project_name_time ON events (project_id, name, occurred_at);
CREATE INDEX idx_events_project_user_time ON events (project_id, user_profile_id, occurred_at);
CREATE INDEX idx_events_properties ON events USING GIN (properties);

-- Idempotency: only index rows that have a key (partial index = no bloat)
CREATE UNIQUE INDEX idx_events_idempotency
  ON events (project_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;
```

**Why partition by month?**
1. **Partition pruning** — A query for "events in March" only scans the March partition, not the entire table. PostgreSQL's query planner handles this automatically.
2. **Data retention** — To delete events older than 12 months: `DROP TABLE events_2025_03`. This is O(1) and instant. `DELETE FROM events WHERE occurred_at < ...` is O(n), locks the table, and leaves bloat that needs VACUUM.
3. **Maintenance** — Smaller partitions mean faster VACUUM, faster index rebuilds, faster backups.

**Why `occurred_at` and not `created_at` for partitioning?**
- Events can arrive late (SDK batching, network delays, imports). The partition should reflect when the event *happened*, not when our server received it.

**Why nullable `user_profile_id`?**
- Anonymous events exist. A JS SDK sends events before the user logs in. These events have no user yet — they'll be backfilled when `identify()` is called later.

**Why a partial unique index for idempotency?**
- Most events don't have an idempotency key (server-side tracking doesn't need it). A full index on a mostly-NULL column wastes space and slows writes.
- `WHERE idempotency_key IS NOT NULL` means only events with keys are indexed. Zero overhead for events without.

### Table: `event_daily_rollups`

```sql
CREATE TABLE event_daily_rollups (
  id          bigserial PRIMARY KEY,
  project_id  bigint NOT NULL REFERENCES projects(id),
  event_name  varchar NOT NULL,
  date        date NOT NULL,
  count       integer NOT NULL DEFAULT 0,
  created_at  timestamp NOT NULL,
  updated_at  timestamp NOT NULL
);

CREATE UNIQUE INDEX idx_rollups_project_event_date
  ON event_daily_rollups (project_id, event_name, date);
```

**Why rollups instead of COUNT(*) at query time?**
- The dashboard asks "how many `subscription-update` events happened per day this month?" If we `COUNT(*)` the events table every time, that's a full scan of the partition. At 10K events, that's slow. At 100K, it's unusable.
- Rollups are O(1) reads. The dashboard query becomes: `SELECT date, count FROM event_daily_rollups WHERE project_id = X AND event_name = Y AND date BETWEEN A AND B`. That's an index scan — instant.

**Why not materialized views?**
- Materialized views do a FULL REFRESH — they recompute everything. With 100K events, that's expensive.
- Rollups are incremental: each new event does `UPDATE count = count + 1` via upsert. The trade-off is write amplification (every event writes twice: once to `events`, once to `rollups`). At our scale, that's fine.

**Why upsert (INSERT ON CONFLICT UPDATE)?**
- Thread-safe, race-condition-free. Two concurrent requests incrementing the same rollup row won't lose a count.

### Table: `identity_aliases`

```sql
CREATE TABLE identity_aliases (
  id               bigserial PRIMARY KEY,
  project_id       bigint NOT NULL REFERENCES projects(id),
  anonymous_id     varchar NOT NULL,
  user_profile_id  bigint NOT NULL REFERENCES user_profiles(id),
  created_at       timestamp NOT NULL
);

CREATE UNIQUE INDEX idx_aliases_project_anonymous
  ON identity_aliases (project_id, anonymous_id);
```

**Why a separate table (not a column on user_profiles)?**
- One identified user can have multiple anonymous IDs (different browsers, devices, incognito sessions). This is a one-to-many relationship.
- Mixpanel, Amplitude, and PostHog all model this as a separate mapping table.

---

## Service Layer — EventIngestionService

### Why a service object (not controller logic, not model callbacks)?

- **Controllers should be thin.** They handle HTTP concerns (params, auth, response codes). Business logic lives in services.
- **Model callbacks create hidden coupling.** An `after_create` on Event that updates rollups means you can't insert an event without side effects. Services make the flow explicit.
- **Testability.** You can test `EventIngestionService.track(...)` without HTTP. You can test the controller without the service (mock it).

### The flow:

```
EventIngestionService.track(project:, event_name:, user_id:, properties:, timestamp:, idempotency_key:)
  │
  ├── 1. Find or create UserProfile (if user_id present)
  │      └── Upsert by (project_id, external_id)
  │      └── Update last_seen_at
  │
  ├── 2. Insert Event
  │      └── ON CONFLICT (idempotency_key) DO NOTHING
  │
  └── 3. Upsert EventDailyRollup
         └── INSERT ... ON CONFLICT (project_id, event_name, date) DO UPDATE SET count = count + 1
```

**Why synchronous (not async)?**
- At <100 events/day, a background queue adds complexity with zero benefit. The entire flow takes <10ms.
- The API returns `202 Accepted` regardless — the HTTP contract is already async. Migrating to a Redis buffer + worker later is a backend-only change. Zero SDK impact.

---

## API Design — Following Industry Patterns

### How Mixpanel, Amplitude, and PostHog do it

| Pattern | Mixpanel | Amplitude | PostHog | Tally |
|---------|----------|-----------|---------|-------|
| Write auth | Project token in body | API key in body | API key in body | `X-API-Key` header |
| Read auth | Basic Auth (service account) | API key + secret | Personal API key | `Bearer` token (api_secret) |
| Single event | POST /track | POST /2/httpapi | POST /capture | POST /api/v1/track |
| Batch | POST /import | POST /2/httpapi (events array) | POST /batch | POST /api/v1/batch |
| Identify | POST /engage ($set) | $identify event type | POST /capture ($identify) | POST /api/v1/identify |
| Alias | $create_alias event | Auto-merge | POST /capture ($create_alias) | POST /api/v1/alias |
| Batch limit | 2000 events / 2MB | 2000 events / 1MB | 20MB | 100 events |

**Why `X-API-Key` header instead of key in body?**
- Cleaner separation. The header is auth, the body is data.
- Middleware can authenticate before parsing the body.
- Stripe, Twilio, and most modern APIs use header-based auth.

**Why separate `/track`, `/identify`, `/alias` endpoints instead of one `/capture` with event types?**
- Explicit is better than implicit. Each endpoint has clear params and a clear purpose.
- Easier to rate-limit differently (e.g., `/batch` gets higher limits than `/track`).
- Better API docs — each endpoint is self-documenting.

**Why 100 event batch limit (not 2000)?**
- We're not Mixpanel. 100 is plenty for a JS SDK flushing every 5 seconds. A lower limit means simpler error handling, smaller request bodies, and faster processing.

---

## Identity Resolution — How Anonymous Becomes Known

```
1. User visits your app (not logged in)
   → JS SDK generates anon_xxxx UUID, stores in localStorage
   → Events are tracked with anonymous user_profile

2. User logs in
   → App calls tally('identify', 'user@email.com')
   → SDK sends POST /api/v1/alias { anonymous_id: "anon_xxxx", user_id: "user@email.com" }
   → SDK sends POST /api/v1/identify { user_id: "user@email.com", properties: {...} }

3. Backend processing
   → Creates IdentityAlias record
   → Enqueues IdentityResolutionJob
   → Job updates: UPDATE events SET user_profile_id = identified WHERE user_profile_id = anonymous
   → Old anonymous UserProfile is deleted

4. Result: all pre-login events now appear in the identified user's timeline
```

**Why localStorage (not cookies)?**
- No cookie banners needed. The UUID never leaves the analytics context.
- Cookies get sent on every HTTP request to the domain — wasteful for a UUID that's only needed by the analytics SDK.
- This is how PostHog does it.

**Why a background job for backfilling (not inline)?**
- A user might have 100+ anonymous events. Updating them inline would make the `/alias` request take seconds instead of milliseconds.
- Eventual consistency is fine here — there's a short window where anonymous events aren't linked, but the dashboard doesn't need real-time accuracy.

---

## Dashboard Architecture

### Why Turbo Frames (not one big page load)

Each dashboard widget loads independently in its own Turbo Frame:
- Event trend chart loads from `/projects/1/widgets/event_chart?from=...&to=...`
- Top events table loads from `/projects/1/widgets/top_events?from=...&to=...`
- Key metrics loads from `/projects/1/widgets/metrics?from=...&to=...`

**Why?**
- **Parallel loads.** Each frame makes its own request. A slow chart query doesn't block the metrics.
- **Independent caching.** Cache each widget separately with different TTLs.
- **Date range updates.** When the user changes the date range, all frames reload simultaneously — no full page refresh.

### Why Chart.js (not D3, not Recharts)

- Lightweight (~60KB). D3 is 250KB+ and way more power than we need.
- Works with Stimulus controllers — pass data via `data-` attributes.
- Line charts and bar charts are all we need. Chart.js does these well.

---

## SDK Design — The #1 Rule: Never Break the Host App

### Ruby SDK — Zero Dependencies

```ruby
TallyAnalytics.track("user@email.com", "subscription-update", plan: "premium")
```

**Why Net::HTTP only?**
- Analytics gems run inside other people's Rails apps. If our gem depends on Faraday 2.x and the host app uses Faraday 1.x, that's a production incident that has nothing to do with analytics. Net::HTTP is in Ruby's stdlib — it's always there, it never conflicts.

**Why fire-and-forget (swallow errors)?**
- Analytics is never on the critical path. If Tally is down, the host app must keep working. Log a warning, move on. This is how every analytics SDK works.

### JS SDK — Batching + sendBeacon

**Why batch events?**
- Without batching, every `tally('track', ...)` call = 1 HTTP request. A page with 5 events = 5 requests. Batching accumulates events in memory and flushes every 5 seconds = 1 request.

**Why `navigator.sendBeacon` on page unload?**
- Regular `fetch()` requests get cancelled when the user navigates away. `sendBeacon` is specifically designed to survive page unloads. Without it, you lose every event that fires right before navigation — that's 10-30% of events.
- This is how Mixpanel and Amplitude do it.

---

## Deployment — Kamal 2

### Why Kamal (the DHH way)

- Ships with Rails 8. It's the intended deployment path.
- Docker-based — your dev environment matches production exactly.
- Zero-downtime deploys with rolling restarts.
- Thruster sits in front of Puma — HTTP/2, asset caching, gzip. No Nginx to configure.
- Works on any VPS ($5/mo DigitalOcean, Hetzner, etc.). Not locked into a PaaS.

### What Kamal sets up

```
Your VPS
├── Thruster (HTTP proxy + compression + caching)
│   └── Puma (Rails app server)
├── Solid Queue worker (background jobs, same Docker image)
└── PostgreSQL (Kamal accessory or managed DB)
```

---

## File Structure

```
/Users/al/Developer.nosync/tally/
├── docs/                              # Design docs (you are here)
│   ├── WHY.md                         # Why this project exists
│   ├── ARCHITECTURE.md                # System design overview
│   ├── API.md                         # API reference
│   ├── SDKS.md                        # SDK design + usage
│   ├── ROADMAP.md                     # 4-week plan
│   ├── IMPLEMENTATION.md              # This file — how + why
│   └── INTERVIEW_TALKING_POINTS.md    # System design discussions
├── app/
│   ├── controllers/
│   │   ├── api/v1/base_controller.rb       # API auth, error handling, rate limiting
│   │   ├── api/v1/track_controller.rb      # POST /api/v1/track
│   │   ├── api/v1/batch_controller.rb      # POST /api/v1/batch
│   │   ├── api/v1/identify_controller.rb   # POST /api/v1/identify
│   │   ├── api/v1/alias_controller.rb      # POST /api/v1/alias
│   │   ├── api/v1/queries_controller.rb    # GET /api/v1/queries/*
│   │   ├── dashboard_controller.rb         # Root — project list
│   │   ├── projects_controller.rb          # Project CRUD + dashboard
│   │   └── users_controller.rb             # User timeline
│   ├── models/
│   │   ├── project.rb
│   │   ├── user_profile.rb
│   │   ├── event.rb
│   │   ├── event_daily_rollup.rb
│   │   └── identity_alias.rb
│   ├── services/
│   │   └── event_ingestion_service.rb      # Core business logic
│   ├── jobs/
│   │   ├── identity_resolution_job.rb      # Backfill anonymous → identified
│   │   └── partition_maintenance_job.rb    # Create future partitions
│   ├── views/                              # Hotwire dashboard
│   └── javascript/controllers/             # Stimulus (chart, date picker)
├── lib/tally_analytics/                    # Ruby SDK (extract to gem later)
├── public/sdk/tally.js                     # JS SDK
├── db/migrate/                             # 5 migrations
├── config/
│   ├── routes.rb
│   └── deploy.yml                          # Kamal config
└── README.md
```

---

## Implementation Order (and why this order)

1. **`rails new` + git init** — Get a running app first. Verify it boots.
2. **5 migrations + models** — The schema IS the system design. Get this right first.
3. **EventIngestionService** — Core business logic, independent of HTTP.
4. **API write endpoints + curl tests** — Now we can receive events. This is the MVP core.
5. **Rollup upsert (inline with ingestion)** — Dashboard will need this. Doing it inline means every event updates rollups immediately.
6. **API read endpoints** — Now we can query data.
7. **Dashboard** — Project CRUD, charts, Turbo Frames. This is where it becomes visual.
8. **Background jobs** — Identity resolution + partition maintenance. Not blocking for MVP but needed for completeness.
9. **Ruby SDK** — So Vroom can send events.
10. **JS SDK** — So Vroom's frontend can send events.
11. **Seed data** — Demo data for the dashboard.
12. **Kamal deploy** — Ship it.

**Why this order?** Each step builds on the previous one. You can test each step independently. At step 4, you have a working API. At step 7, you have a working product. Steps 8-12 are polish.
