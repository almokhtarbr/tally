# Roadmap

_Status as of 2026-09. The original week-by-week build plan is done; this
tracks what's shipped and what's next. Work is tracked as GitHub issues +
PRs on `almokhtarbr/tally`._

## Shipped

**Core** — event tracking (`/track`, `/batch`, `/identify`, `/alias`), identity
resolution, idempotency, rate limiting, monthly-partitioned `events` table,
pre-aggregated `EventDailyRollup`s.

**Analytics** — trends, funnels (with property filters), retention cohorts,
top events/pages, event explorer with property breakdown, user timeline,
bounce rate, period-over-period comparison.

**Product** — real-time dashboard, error tracking + grouping, form analytics,
user paths, anomaly detection (z-score) with webhook alerts, segments, saved
reports, CSV export, HMAC webhooks with auto-disable.

**SDKs** — Ruby, JavaScript, Python, Node (all zero-dependency).

**Recent (this cycle)**
- Fixed the test suite (default `events` partition, stale `structure.sql`,
  auto-build Tailwind) + added CI (rspec / rubocop / brakeman). — #1
- **Weekly email digest** per project, opt-out per member. — #3
- **O(1) data retention** — `DropExpiredPartitionsJob` drops aged-out month
  partitions past `EVENTS_RETENTION_MONTHS`. — #4
- **Slack-formatted webhooks** — a `hooks.slack.com` URL gets a readable
  message, not raw JSON. — #5

## Next

Priority order — small, self-contained, each a PR:

1. **Per-project retention** — a `retention_months` on the project for teams
   that want shorter windows than the global partition drop (scoped delete).
2. **Public shareable dashboard link** — read-only tokenised view of a
   project's dashboard.
3. **Custom dashboards** — more than one saved layout per project (build on
   `SavedReport`).
4. **Multi-property breakdown on trends** — group-by two dimensions.
5. **Email verification / password reset** for the auth flow.
6. **Go SDK** — the one server language not yet covered.

## Not building (out of scope)

Session replay, feature flags, A/B testing, surveys, SQL/warehouse access,
NL queries. See `FEATURE_COMPARISON.md` — the angle is the focused 20%, not
Amplitude/PostHog parity.
