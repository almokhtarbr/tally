# Tally Codebase Reading Guide

A structured tour of the entire Tally codebase. Each chapter covers one logical area, explains what it does in plain English, lists the files involved, and shows how the pieces connect. You can read any chapter on its own.

---

## Chapter 1: The Foundation

Tally is a self-hosted product analytics service — a focused replacement for Mixpanel. You add a tracking snippet to your app, events flow in through an API, and Tally stores them, rolls them up, and displays trends on a dashboard. It supports five SDKs (JS, Ruby, Python, Node, Go), user identification, funnels, retention analysis, error tracking, anomaly detection, and webhooks.

### The core database tables

Everything in Tally revolves around five tables:

| Table | What it stores |
|---|---|
| `projects` | A monitored app. Has a public `api_key` (pk\_...) for writing and a private `api_secret` (sk\_...) for reading. |
| `user_profiles` | An identified user within a project. Stores flexible JSONB `properties` (plan, email, country — whatever you set). |
| `events` | Something a user did. Append-only, partitioned by month on `occurred_at`. JSONB `properties` for arbitrary data. |
| `event_daily_rollups` | Pre-aggregated event counts per project + event name + date. The dashboard reads from this instead of scanning millions of raw events. |
| `identity_aliases` | Maps an anonymous ID to an identified user profile, so pre-login events can be attributed after login. |

### Files to read

| File | What to look for |
|---|---|
| `db/structure.sql` | The full SQL schema — partitioned events table, JSONB columns, partial unique indexes for idempotency |
| `db/migrate/20260315220001_create_projects.rb` | Projects table with api_key and api_secret columns |
| `db/migrate/20260315220002_create_user_profiles.rb` | User profiles with JSONB properties, external_id uniqueness |
| `db/migrate/20260315220003_create_events.rb` | Partitioned events table (range on occurred_at) |
| `db/migrate/20260315220004_create_event_daily_rollups.rb` | Rollup table with unique constraint on (project, event_name, date) |
| `db/migrate/20260315220005_create_identity_aliases.rb` | Anonymous-to-identified mapping |
| `app/models/project.rb` | Hub model — has_many for every other model. Auto-generates pk\_ and sk\_ keys on create |
| `app/models/event.rb` | Slim model — belongs_to project and optional user_profile, scopes for date ranges |
| `app/models/user_profile.rb` | `merge_properties!` method for the identify flow — merges JSONB without overwriting |
| `app/models/event_daily_rollup.rb` | `increment!` class method — atomic upsert that's thread-safe with no race conditions |
| `app/models/identity_alias.rb` | Simple join — links anonymous_id to user_profile within a project |

**Reading order:** Start with `project.rb` to see the has_many relationships, then `event.rb` and `user_profile.rb` to understand the two main data types, then `event_daily_rollup.rb` to see how reads are optimized, then `identity_alias.rb` for the identity linking story.

---

## Chapter 2: How Events Get In (the Write Path)

When your app calls `tally.track("purchase", { amount: 49.99 })`, here's what happens:

1. The SDK sends a POST to `/api/v1/track` with an `X-API-Key` header
2. `BaseController` authenticates the project by looking up the API key
3. `TrackController` extracts params and delegates to `EventIngestionService.track`
4. The service upserts a user profile (if user_id is present), inserts the event (with idempotency support), increments the daily rollup, broadcasts via Turbo Streams, and fires matching webhooks

### Files to read

| File | What to look for |
|---|---|
| `config/routes.rb` (lines 6-18) | The four write endpoints: track, batch, identify, alias. Plus three read endpoints under queries. |
| `app/controllers/api/v1/base_controller.rb` | Two auth methods: `authenticate_project!` (X-API-Key for writes) and `authenticate_project_secret!` (Bearer token for reads). Also handles sendBeacon's text/plain quirk by manually parsing JSON. |
| `app/controllers/api/v1/track_controller.rb` | Thin controller — validates params, calls the service, returns 202. Rate-limited to 100 req/min per API key. |
| `app/controllers/api/v1/batch_controller.rb` | Loops up to 100 events and calls the service for each. Rate-limited to 50 req/min. |
| `app/controllers/api/v1/identify_controller.rb` | Sets or updates user properties via `EventIngestionService.identify`. |
| `app/controllers/api/v1/alias_controller.rb` | Links anonymous_id to user_id via `EventIngestionService.create_alias`. Kicks off `IdentityResolutionJob`. |
| `app/services/event_ingestion_service.rb` | **The most important file in the codebase.** Three class methods: `track`, `identify`, `create_alias`. Track does: upsert user profile, insert event (with idempotency), increment rollup, update counter cache, broadcast, fire webhooks. |

**Reading order:** Start with `routes.rb` to see the endpoints, then `base_controller.rb` for auth, then `track_controller.rb` as the simplest example, then `event_ingestion_service.rb` to see the full write path. Read batch/identify/alias last — they follow the same pattern.

**Connects to:** Chapter 1 (the tables being written to), Chapter 6 (identity resolution triggered by alias), Chapter 10 (webhooks fired after track).

---

## Chapter 3: How Events Come Out (the Read Path)

Data leaves Tally two ways: through the API (for programmatic access) and through the dashboard (for humans).

### The API read path

The queries controller uses Bearer token auth (api_secret) instead of API key auth. It reads from `event_daily_rollups` for fast aggregations and from `events` for user timelines.

### The dashboard read path

The `ProjectsController#show` action is the main dashboard. It computes stats (visitors, pageviews, sessions, custom events) by reading from rollups and comparing the current date range to the previous period for trend arrows. Chart data is grouped by day and rendered with Chart.js.

### Files to read

| File | What to look for |
|---|---|
| `app/controllers/api/v1/queries_controller.rb` | Three endpoints: `event_counts` (time series from rollups), `top_events` (ranked event names), `user_timeline` (raw events for one user). Note: skips default auth and uses secret-based auth instead. |
| `app/controllers/projects_controller.rb` (show action, ~line 15) | The dashboard query logic — date ranges, rollup aggregations, trend calculations, top pages, referrers, devices. Heavy method — this is where most of the SQL lives. |
| `app/models/event_daily_rollup.rb` | The `increment!` method (write path) and the model that dashboard queries hit (read path). One row = one project + event name + date + count. |

**Reading order:** Start with `queries_controller.rb` (cleaner, API-focused), then read the `show` action in `projects_controller.rb` (more complex, UI-focused).

**Connects to:** Chapter 2 (rollups written during ingestion), Chapter 4 (views that render this data).

---

## Chapter 4: The Dashboard (What Users See)

The dashboard is a server-rendered Hotwire app. No SPA — just ERB templates with Turbo Streams for real-time updates and Stimulus for interactive widgets.

### Layout and navigation

The main layout provides the shell (sidebar, nav). Each project page uses shared partials for the header, tab navigation, and date picker. Tabs link to different analytics views (overview, event explorer, funnels, retention, users, etc.).

### Files to read

| File | What to look for |
|---|---|
| `app/views/layouts/application.html.erb` | The outer shell — sidebar nav, Turbo/Stimulus includes, Tailwind styles. Look for the turbo_stream_from tag that enables real-time updates. |
| `app/views/layouts/session.html.erb` | Simpler layout used for login/setup pages (no sidebar). |
| `app/views/projects/_page_header.html.erb` | Project name, date range display, shared across all project views. |
| `app/views/projects/_project_tabs.html.erb` | Tab navigation — Overview, Event Explorer, Funnels, Retention, Users, Errors, etc. This is your map of all analytics features. |
| `app/views/projects/_date_picker.html.erb` | Date range selector used on every analytics view. |
| `app/views/projects/show.html.erb` | The main dashboard — stat cards (visitors, pageviews, sessions), trend charts, top pages, referrers. |
| `app/views/dashboard/index.html.erb` | The landing page — lists all projects with their event counts. |
| `app/javascript/controllers/chart_controller.js` | Stimulus controller that initializes Chart.js — look for how it reads data attributes from the HTML to render charts. |

**Reading order:** Start with `application.html.erb` for the outer shell, then `_project_tabs.html.erb` to see all the features, then `show.html.erb` for the main dashboard, then `chart_controller.js` for the chart rendering.

**Connects to:** Chapter 3 (controller actions that feed data to these views), Chapter 7 (each tab links to a feature view).

---

## Chapter 5: Authentication and Team Management

Tally uses cookie-based session auth with `has_secure_password`. There's a first-run setup flow, then standard login/logout.

### How it works

1. **First run:** If no User records exist, every request redirects to `/setup` where you create the first admin account
2. **Login:** Email/password authentication creates a `Session` record with a secure token stored in a signed cookie
3. **Request cycle:** `Authentication` concern loads the session from the cookie on every request, sets `Current.user`
4. **Roles:** Users are `admin` or `member`. Projects have `ProjectMembership` with roles: `owner`, `editor`, `viewer`

### Files to read

| File | What to look for |
|---|---|
| `app/models/current.rb` | `CurrentAttributes` — stores the session per-request. `Current.user` delegates to `session.user`. |
| `app/models/session.rb` | `has_secure_token` generates a random token on create. Belongs to user. |
| `app/models/user.rb` | `has_secure_password` for bcrypt. Roles: admin/member. `can_access_project?` checks admin or membership. |
| `app/models/project_membership.rb` | Links users to projects. Roles: owner, editor, viewer. |
| `app/controllers/concerns/authentication.rb` | The concern included by every web controller. `require_setup` redirects to setup if no users exist. `authenticate!` loads session from cookie. `start_new_session` / `end_session` manage the cookie. |
| `app/controllers/setup_controller.rb` | First-run only — creates the admin user, starts a session, redirects to dashboard. Blocked if users already exist. |
| `app/controllers/sessions_controller.rb` | Login/logout — finds user by email, authenticates password, creates session. Uses the `session` layout (no sidebar). |
| `app/controllers/users_controller.rb` | Admin-only user management (invite, edit role, delete). Plus `edit_profile`/`update_profile` for any user to change their own name/password. |
| `app/views/setup/new.html.erb` | The first-run setup form. |
| `app/views/sessions/new.html.erb` | The login page. |
| `app/views/users/index.html.erb` | Team management list (admin only). |

**Reading order:** Start with `current.rb` (3 lines, sets the pattern), then `authentication.rb` (the concern that ties it together), then `setup_controller.rb` (first-run flow), then `sessions_controller.rb` (login flow).

**Connects to:** Chapter 4 (layout uses `current_user` for nav), Chapter 2 (API auth is separate — X-API-Key, not sessions).

---

## Chapter 6: Identity Resolution

Users start anonymous (a random ID from the JS SDK) and become identified when they log in or sign up. Identity resolution links the anonymous history to the real user.

### How it works

1. JS SDK generates an `anonymous_id` and sends it with every event
2. When the user logs in, the app calls `tally.identify("user-123", { name: "Alice" })`
3. The SDK also calls `tally.alias(anonymous_id, "user-123")`
4. This creates an `IdentityAlias` record and enqueues `IdentityResolutionJob`
5. The job finds the anonymous user profile, re-links all its events to the identified profile, merges properties, and deletes the anonymous profile

### Files to read

| File | What to look for |
|---|---|
| `app/models/identity_alias.rb` | Simple mapping: anonymous_id -> user_profile, scoped to project. |
| `app/services/event_ingestion_service.rb` (create_alias, line 72) | Creates the alias record and enqueues the background job. |
| `app/jobs/identity_resolution_job.rb` | The actual resolution: finds anonymous profile, re-links events with `update_all`, merges properties, updates `first_seen_at`, deletes anonymous profile. Handles missing records gracefully. |
| `public/sdk/tally.js` | Look for the `identify` and `alias` methods — the JS SDK calls both endpoints and swaps the anonymous_id for the real user_id. |

**Reading order:** Start with `identity_alias.rb` (the data model), then the `create_alias` method in the service, then `identity_resolution_job.rb` for the background work.

**Connects to:** Chapter 2 (alias endpoint triggers this), Chapter 11 (SDKs that call identify/alias).

---

## Chapter 7: Analytics Features

Each analytics feature follows the same pattern: a controller action in `ProjectsController` queries the data, and a view in `app/views/projects/` renders it. The `_project_tabs.html.erb` partial links to all of them.

### Event Explorer

Browse, filter, and group events. Pick an event name, date range, and optional property grouping to see a breakdown.

| File | What it does |
|---|---|
| `app/controllers/projects_controller.rb` (event_explorer action) | Queries events with filters (event name, property key/value), groups results, paginates |
| `app/views/projects/event_explorer.html.erb` | Filter form, results table, property breakdown charts |

### Funnels

Multi-step conversion tracking. Define 2+ steps (event names), see how many users complete each step and where they drop off.

| File | What it does |
|---|---|
| `app/controllers/projects_controller.rb` (funnels action) | Runs a multi-step funnel query — finds users who did step 1, then step 2, etc. within a time window |
| `app/views/projects/funnels.html.erb` | Step selector, conversion percentages, funnel visualization |

### Retention

Cohort stickiness analysis. Groups users by when they first appeared and shows what percentage came back in subsequent periods.

| File | What it does |
|---|---|
| `app/controllers/projects_controller.rb` (retention action) | Builds a cohort matrix — groups users by first-seen week/month, checks return rates |
| `app/views/projects/retention.html.erb` | Retention grid/heatmap with percentages |

### User Paths

Navigation flow visualization. Shows common sequences of events (page A -> page B -> page C).

| File | What it does |
|---|---|
| `app/controllers/projects_controller.rb` (user_paths action) | Queries sequential events per user, builds path trees |
| `app/views/projects/user_paths.html.erb` | Sankey-style flow diagram of user navigation |

### Forms

Form completion and abandonment analytics. Tracks which fields users interact with and where they drop off.

| File | What it does |
|---|---|
| `app/controllers/projects_controller.rb` (forms action) | Aggregates $form_submit, $input_change, and $field_time events |
| `app/views/projects/forms.html.erb` | Form list, field-level completion rates, time-per-field |

### Users

Browse identified users, see their properties and activity.

| File | What it does |
|---|---|
| `app/controllers/projects_controller.rb` (users action) | Lists user profiles with search/filter |
| `app/controllers/projects_controller.rb` (user_profile action) | Shows one user's properties and event timeline |
| `app/views/projects/users.html.erb` | User list with properties |
| `app/views/projects/user_profile.html.erb` | Individual user detail page |

### Segments

Saved user cohorts with behavioral and property conditions. Used to filter other reports.

| File | What it does |
|---|---|
| `app/models/segment.rb` | Defines condition format (event-based and property-based), `matching_user_ids` executes the query |
| `app/controllers/segments_controller.rb` | Full CRUD — list, create, show (with matching users), edit, delete |
| `app/views/segments/` (all files) | Index, new/edit form with condition builder, show page with user list |

### Saved Reports

Persist any report configuration (funnel, retention, event explorer) so you can revisit it later.

| File | What it does |
|---|---|
| `app/models/saved_report.rb` | Stores report_type and JSONB configuration. `to_query_params` converts it back to URL params. |
| `app/controllers/saved_reports_controller.rb` | Create (saves current filters), show (redirects to the report with saved params), destroy |
| `app/views/saved_reports/index.html.erb` | Lists saved reports grouped by type |

**Connects to:** Chapter 3 (all these read from the same rollup/event data), Chapter 4 (all rendered within the dashboard layout).

---

## Chapter 8: Error Tracking and Business Impact

The JS SDK auto-captures JavaScript errors, unhandled promise rejections, and network failures. The dashboard groups them, shows breadcrumbs, and correlates errors with revenue impact.

### How it works

1. JS SDK catches `window.onerror`, `unhandledrejection`, and failed `fetch` calls
2. Each error is sent as a `$error`, `$promise_error`, or `$network_error` event with stack trace, URL, and breadcrumbs in properties
3. The `errors` action groups errors by message and shows frequency
4. The `error_detail` action shows one error group's stack trace, affected users, breadcrumbs, and business impact

### Files to read

| File | What to look for |
|---|---|
| `public/sdk/tally.js` | Look for `setupErrorTracking` — hooks into window.onerror, unhandledrejection, and patches fetch/XMLHttpRequest for network errors. Captures breadcrumbs (clicks, navigations) leading up to errors. |
| `app/controllers/projects_controller.rb` (errors action) | Groups error events by message, counts occurrences and affected users |
| `app/controllers/projects_controller.rb` (error_detail action) | Fetches one error group, computes business impact by correlating error users with revenue events |
| `app/views/projects/errors.html.erb` | Error list with frequency, last seen, trend sparklines |
| `app/views/projects/error_detail.html.erb` | Stack trace, breadcrumb timeline, affected users, revenue impact estimate |

**Connects to:** Chapter 2 (errors are just events flowing through the normal write path), Chapter 11 (JS SDK's error capture code).

---

## Chapter 9: Anomaly Detection

Tally automatically detects unusual spikes, drops, or absences in event volume using z-score statistics. It runs every 10 minutes.

### How it works

1. `AnomalyDetectionJob` runs on a recurring schedule (every 10 minutes)
2. For each project, it looks at the last 7 days of rollup data per event name
3. It computes the mean and standard deviation, then calculates a z-score for today's count
4. If the z-score exceeds 2.5 (the threshold), it creates an `Anomaly` record
5. Anomalies are classified as `spike`, `drop`, or `absence` with severity levels: `info` (z > 2.5), `warning` (z > 3), `critical` (z > 4)
6. Active anomalies older than 24 hours are auto-resolved if the event returns to normal
7. New anomalies fire webhooks to any webhook subscribed to the "anomaly" event

### Files to read

| File | What to look for |
|---|---|
| `app/models/anomaly.rb` | Types (spike/drop/absence), severities (info/warning/critical), `description` method for human-readable text, `severity_for_z_score` class method |
| `app/jobs/anomaly_detection_job.rb` | The detection algorithm: lookback window, z-score calculation, deduplication (no duplicate active anomalies within 24h), auto-resolution, webhook firing |
| `app/controllers/projects_controller.rb` (anomalies action) | Queries active and recent anomalies for the dashboard |
| `app/views/projects/anomalies.html.erb` | Anomaly list with severity badges, acknowledge/resolve buttons |
| `config/recurring.yml` | Schedule: `every 10 minutes` in both development and production |

**Reading order:** Start with `anomaly.rb` (the data model and severity logic), then `anomaly_detection_job.rb` (the algorithm), then the view.

**Connects to:** Chapter 1 (reads from rollups), Chapter 10 (fires webhooks on detection), Chapter 12 (recurring job schedule).

---

## Chapter 10: Webhooks

HTTP callbacks that fire when events are tracked or anomalies are detected. Supports HMAC signing and auto-disables after repeated failures.

### How it works

1. You create a webhook for a project, choosing which events to subscribe to (or `*` for all)
2. When an event is tracked, `EventIngestionService` checks for matching webhooks and enqueues `WebhookDeliveryJob`
3. The job POSTs JSON to the webhook URL with headers: `X-Tally-Event` (event name) and `X-Tally-Signature` (HMAC-SHA256)
4. On success (2xx), failure count resets. On failure, count increments. After 10 consecutive failures, the webhook auto-disables.
5. Secrets are prefixed `whsec_` and auto-generated on create

### Files to read

| File | What to look for |
|---|---|
| `app/models/webhook.rb` | `matches_event?` (wildcard support), `sign_payload` (HMAC-SHA256), `record_failure!` (auto-disable after 10), `record_success!` (reset failures) |
| `app/jobs/webhook_delivery_job.rb` | HTTP delivery with timeouts (5s connect, 10s read), header construction, success/failure recording |
| `app/controllers/webhooks_controller.rb` | Full CRUD plus `toggle` (enable/disable) and `test` (sends a test payload). `available_events` pulls distinct event names from rollups. |
| `app/views/webhooks/` (all files) | Index with status badges, form with event selector, edit page |

**Reading order:** Start with `webhook.rb` (the model with signing and failure logic), then `webhook_delivery_job.rb` (the actual HTTP call), then the controller.

**Connects to:** Chapter 2 (webhooks fired during ingestion), Chapter 9 (anomaly detection also fires webhooks).

---

## Chapter 11: The SDKs

Tally ships four SDKs. All follow the same pattern: buffer events in memory, flush in batches, and provide `track`, `identify`, and `alias` methods.

### JS SDK (browser)

The most feature-rich SDK. Runs in the browser, auto-captures pageviews, sessions, clicks, scroll depth, errors, form interactions, and more.

| File | What to look for |
|---|---|
| `public/sdk/tally.js` | Single-file SDK. Key sections: `init` (config and anonymous ID), `track`/`identify`/`alias` (core methods), `setupAutoCapture` (pageviews, sessions, clicks), `setupErrorTracking` (JS errors, network failures), `setupFormTracking` (field-level analytics), flush queue with `sendBeacon` fallback |

### Ruby SDK (server-side)

Zero-dependency gem using Net::HTTP with background thread batching. Includes a Rails integration via Railtie.

| File | What to look for |
|---|---|
| `lib/tally_analytics.rb` | Entry point — module-level `configure`, `track`, `identify`, `alias_user` methods that delegate to a global client |
| `lib/tally_analytics/client.rb` | HTTP client with batch queue, background flush thread, shutdown hook |
| `lib/tally_analytics/configuration.rb` | Config object — api_key, api_url, batch_size, flush_interval |
| `lib/tally_analytics/railtie.rb` | Auto-configures from Rails credentials and adds request context capture |
| `lib/tally_analytics/request_context.rb` | Rack middleware that captures IP, user agent, referrer for server-side events |

### Python SDK

Zero-dependency, uses urllib. Same batching pattern as Ruby.

| File | What to look for |
|---|---|
| `sdks/python/tally_analytics/__init__.py` | Package entry — re-exports the client class |
| `sdks/python/tally_analytics/client.py` | TallyAnalytics class with track/identify/alias, background thread flushing, context manager support |
| `sdks/python/setup.py` | Package metadata for pip install |

### Node.js SDK

Zero-dependency, uses built-in http/https. Includes TypeScript definitions.

| File | What to look for |
|---|---|
| `sdks/node/index.js` | TallyAnalytics class with track/identify/alias, batch queue, setInterval flushing, graceful shutdown |
| `sdks/node/index.d.ts` | TypeScript type definitions for all methods and config options |
| `sdks/node/package.json` | Package metadata for npm install |

**Connects to:** Chapter 2 (all SDKs hit the same API endpoints), Chapter 6 (identify/alias trigger identity resolution), Chapter 8 (JS SDK captures errors).

---

## Chapter 12: Background Jobs and Infrastructure

### Background jobs

Tally uses Solid Queue (Rails 8's default) for background processing. Three custom jobs plus the standard queue cleanup:

| Job | What it does | Schedule |
|---|---|---|
| `PartitionMaintenanceJob` | Creates PostgreSQL partitions for the events table 3 months ahead | Daily at 2am |
| `AnomalyDetectionJob` | Scans all projects for unusual event patterns | Every 10 minutes |
| `IdentityResolutionJob` | Re-links anonymous events to identified users | On-demand (enqueued by alias endpoint) |
| `WebhookDeliveryJob` | Delivers webhook HTTP payloads | On-demand (enqueued by ingestion service) |

### Infrastructure files

| File | What to look for |
|---|---|
| `config/recurring.yml` | Cron-style schedule for recurring jobs — partition maintenance and anomaly detection |
| `config/queue.yml` | Solid Queue configuration |
| `Procfile.dev` | Development processes: `web` (Rails server) and `css` (Tailwind watcher) |
| `Dockerfile` | Production container — multi-stage build for Rails 8 + Thruster |
| `config/deploy.yml` | Kamal 2 deployment configuration |
| `config/database.yml` | PostgreSQL connection settings |
| `config/puma.rb` | Puma web server config (threads, workers) |
| `config/initializers/rack_attack.rb` | Rate limiting configuration |

### Key infrastructure concepts

- **Event partitioning:** The events table is partitioned by month. `PartitionMaintenanceJob` ensures partitions exist 3 months ahead so inserts never fail.
- **Solid Queue:** Replaces Redis-based queues (Sidekiq). Jobs are stored in PostgreSQL — one fewer dependency to operate.
- **Thruster:** HTTP/2 proxy that sits in front of Puma in production (configured in the Dockerfile).

**Connects to:** Chapter 1 (partition maintenance for the events table), Chapter 9 (anomaly detection job), Chapter 10 (webhook delivery job).

---

## Chapter 13: Tests

Tally uses RSpec with FactoryBot. Tests are organized by type, mirroring the app structure.

### How to run

```bash
# All tests
bundle exec rspec

# One file
bundle exec rspec spec/models/project_spec.rb

# One test
bundle exec rspec spec/models/project_spec.rb:15
```

### Test structure

| Directory | What it tests | Count |
|---|---|---|
| `spec/models/` | Validations, associations, business logic on models | 10 specs |
| `spec/services/` | EventIngestionService — the core business logic | 1 spec |
| `spec/jobs/` | Background job behavior (identity resolution, partitions, webhooks, anomalies) | 4 specs |
| `spec/requests/api/v1/` | API endpoint integration tests (track, batch, identify, alias, queries) | 5 specs |
| `spec/requests/` | Web endpoint tests (auth, dashboard, projects, segments, reports, webhooks, users) | 7 specs |
| `spec/factories/` | FactoryBot definitions for all models | 11 factories |

### Files to read

| File | What to look for |
|---|---|
| `spec/rails_helper.rb` | RSpec configuration — transactional fixtures, FactoryBot syntax, request spec helpers |
| `spec/support/request_spec_helpers.rb` | `sign_in` (creates a session via POST), `api_headers` (X-API-Key), `bearer_headers` (Bearer token) — the three auth patterns used across all request specs |
| `spec/factories/projects.rb` | How test projects are built — look here to understand the default test data |
| `spec/services/event_ingestion_service_spec.rb` | The most important spec — tests the full track/identify/alias flow |
| `spec/requests/api/v1/track_spec.rb` | Good example of an API request spec — shows auth, params, and response assertions |

**Reading order:** Start with `rails_helper.rb` and `request_spec_helpers.rb` to understand the test setup, then read one factory and one request spec to see the pattern. After that, any spec file will be immediately readable.

---

## Quick Reference: File Count by Area

| Area | Files | Entry point |
|---|---|---|
| Models | 14 | `app/models/project.rb` |
| Controllers | 12 | `app/controllers/projects_controller.rb` |
| Views | ~30 | `app/views/layouts/application.html.erb` |
| Jobs | 5 | `app/jobs/anomaly_detection_job.rb` |
| Services | 1 | `app/services/event_ingestion_service.rb` |
| API controllers | 5 | `app/controllers/api/v1/base_controller.rb` |
| JS SDK | 1 | `public/sdk/tally.js` |
| Ruby SDK | 5 | `lib/tally_analytics.rb` |
| Python SDK | 3 | `sdks/python/tally_analytics/client.py` |
| Node SDK | 3 | `sdks/node/index.js` |
| Specs | 40 | `spec/rails_helper.rb` |
| Config | ~20 | `config/routes.rb` |
| Migrations | 12 | `db/migrate/` (read in order) |
| Docs | 12 | `docs/` |
