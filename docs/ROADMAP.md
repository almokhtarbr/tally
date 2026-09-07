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
- **Per-project retention** — `retention_days` on the project, enforced by a
  scoped nightly delete for teams wanting a shorter window than the global
  partition drop. — #6
- **Public shareable dashboard link** — read-only tokenised project view at
  `/s/:token`, `noindex`. — #7
- **Go SDK** — zero-dependency client with background flush. — #9
- **Password reset** — `generates_token_for` single-use 30-minute link,
  wipes sessions on reset. — #10
- **Custom dashboards** — any number of named boards per project; pin saved
  reports as widgets, count-shaped reports show a headline metric. — #11

## Next

Priority order — small, self-contained, each a PR:

1. **Multi-property breakdown on trends** — group-by two dimensions. _(the
   query + view already exist in the event explorer; needs a dedicated spec
   and a UX pass.)_
2. **Email verification** for new accounts, reusing the reset-token pattern.
3. **Scheduled report exports** — email a saved report's CSV on a cadence.

## Not building (out of scope)

Session replay, feature flags, A/B testing, surveys, SQL/warehouse access,
NL queries. See `FEATURE_COMPARISON.md` — the angle is the focused 20%, not
Amplitude/PostHog parity.
