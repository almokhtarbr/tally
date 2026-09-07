# Tally Analytics — Gap Analysis vs Amplitude & Mixpanel

Last updated: March 16, 2026

> **Out of date — read `ROADMAP.md` for current status.** Since this was
> written, the codebase shipped: segments, saved reports, webhooks (HMAC +
> Slack-formatted), anomaly detection, sessions, funnel/retention property
> filters, multi-user auth with roles, a full RSpec suite + CI, weekly email
> digests, O(1) + per-project data retention, a public read-only dashboard
> link, and a Go SDK. The "Priority 1" gaps below (property filtering,
> segmentation, CSV export, webhooks/alerts) are **done**. The doc is kept for
> the competitive framing, not the status.

---

## 1. Is Tally Generic (Not Tied to Vroom)?

**YES — fully generic.** No hardcoded references to Vroom anywhere in:
- API endpoints, models, services, jobs
- JS SDK (`tally.js`) and Ruby SDK (`tally_analytics`)
- Dashboard controllers and views

Multi-project architecture means any number of apps can plug in with their own API keys. The SDKs configure endpoint dynamically. **This is already production-ready for any app.**

---

## 2. What We Already Have (That Amplitude/Mixpanel Have)

| Category | Feature | Status |
|----------|---------|--------|
| **Core Tracking** | Event tracking with properties | Done |
| | Batch event ingestion | Done |
| | User identification | Done |
| | Identity resolution (anon→known) | Done |
| | Idempotency / deduplication | Done |
| **Autocapture** | Pageviews, clicks, forms, scroll | Done |
| | Rage clicks, dead clicks | Done (even Amplitude doesn't have this) |
| | JS/network error tracking | Done |
| | Session tracking with duration | Done |
| | UTM params, referrer, device info | Done |
| **Analytics** | Trend charts (time series) | Done |
| | Funnels with conversion windows | Done |
| | Retention cohorts (daily/weekly) | Done |
| | Top events / top pages | Done |
| | Event explorer with property breakdown | Done |
| | User timeline with session grouping | Done |
| | Bounce rate | Done |
| | Period-over-period comparison (%) | Done |
| **Dashboard** | Real-time live event feed | Done |
| | Error dashboard with grouping | Done |
| | User directory with search | Done |
| **SDKs** | JavaScript (SPA-aware, batching) | Done |
| | Ruby (zero-dep, async threads) | Done |
| **Infra** | Rate limiting | Done |
| | CORS support | Done |
| | Monthly partitioning | Done |
| | Pre-aggregated rollups | Done |
| | Docker + Kamal deployment | Done |

**We cover roughly 70-75% of what a typical Mixpanel/Amplitude user actually uses day-to-day.** Most users of those tools only use tracking, funnels, retention, and trends — which we have.

---

## 3. What's Missing — Must-Have (Priority 1)

These are features that paying customers would expect before choosing Tally over free-tier Mixpanel/Amplitude:

### 3a. Property Filtering on Funnels & Retention
**Amplitude/Mixpanel:** "Show me the funnel for users on iOS only" or "Retention for users who signed up via Google Ads"
**Tally now:** Funnels and retention work on all users — no way to filter by user or event properties.
**Impact:** Without this, funnels/retention are too blunt. This is the #1 gap.

### 3b. Segmentation / User Cohorts
**Amplitude/Mixpanel:** "Users who did X but not Y in the last 30 days" — save as a segment, use it everywhere.
**Tally now:** No saved segments. Can't filter any report by behavioral criteria.
**Impact:** Core to how product teams use analytics. Without it, every analysis is "all users."

### 3c. Multi-Property Breakdown on Trends
**Amplitude/Mixpanel:** "Show me signups broken down by country AND plan type"
**Tally now:** Event explorer supports single group-by. No multi-dimensional breakdown.
**Impact:** Medium. Single group-by covers 80% of cases, but power users need more.

### 3d. Data Export / CSV
**Impact:** Table stakes. People want their data out.

### 3e. Webhooks / Alerts
**Impact:** "Notify Slack when someone churns" — this is what makes analytics actionable.

---

## 4. What's Missing — Important (Priority 2)

### 4a. User Paths / Flow Analysis
**Amplitude:** Journeys feature — visualize how users navigate A→B→C→D.
**Mixpanel:** Flows report.
**Tally:** Nothing. We have user timelines but no aggregate path visualization.
**Impact:** Answers "how do users actually move through my app?" — very valuable but hard to build.

### 4b. Team Members / Roles
**Tally now:** Single admin login via HTTP Basic Auth (hardcoded ADMIN_USER/ADMIN_PASSWORD).
**Impact:** Any team >1 person needs individual logins. Blocker for B2B adoption.

### 4c. Saved Reports / Bookmarks
**Amplitude/Mixpanel:** Save any chart/query, share a link, pin to dashboard.
**Tally now:** Nothing persisted. Every analysis starts from scratch.
**Impact:** Power users won't tolerate rebuilding reports every time.

### 4d. Custom Dashboards
**Amplitude/Mixpanel:** Drag-and-drop dashboard builder with multiple charts.
**Tally now:** One fixed dashboard layout per project.
**Impact:** Teams want their own views. Marketing cares about different metrics than engineering.

### 4e. Email Digests / Scheduled Reports
**Amplitude/Mixpanel:** "Email me a weekly summary every Monday."
**Tally now:** Nothing.
**Impact:** Nice for engagement but not blocking.

### 4f. More SDKs
**Amplitude:** Python, Node, Go, Java, Swift, Kotlin, Flutter, React Native
**Mixpanel:** Same
**Tally:** Ruby + JavaScript only
**Impact:** Any non-Ruby backend can't use server-side tracking without raw HTTP calls. Python and Node SDKs would cover 90% of use cases.

---

## 5. What Could Be Improved (Existing Features)

### 5a. Test Coverage — CRITICAL
**Current state: ZERO automated tests.** No unit, integration, or system tests.
Before adding features, the codebase needs:
- Model specs (validations, scopes, methods)
- Service specs (EventIngestionService — the core logic)
- API request specs (all 7 endpoints)
- Job specs (IdentityResolutionJob, PartitionMaintenanceJob)

### 5b. Projects Controller is 782 Lines
All dashboard logic lives in one massive controller. Should be broken into:
- `FunnelsController`
- `RetentionController`
- `EventExplorerController`
- `ErrorsController`
- `UsersController`
Each with its own query service object.

### 5c. Authentication
HTTP Basic Auth is fine for a solo developer but doesn't scale. Should eventually support:
- Individual user accounts
- Invite links
- API token management UI

### 5d. Query Performance at Scale
Funnels and retention query raw events. At 100K+ events/day, these will get slow.
- Funnels should use materialized views or pre-computed conversion data
- Retention could use rollup tables similar to EventDailyRollup

### 5e. Ruby SDK Missing Batching
JS SDK batches events (flush every 5s, max 100). Ruby SDK sends one HTTP request per event in a background thread. Should batch for higher-throughput server environments.

---

## 6. Summary Scorecard vs Amplitude/Mixpanel

| Area | Amplitude | Mixpanel | Tally | Gap |
|------|-----------|----------|-------|-----|
| Event tracking | 10 | 10 | 9 | Missing batching in Ruby SDK |
| Autocapture | 7 | 5 | 9 | Tally actually leads here |
| Funnels | 10 | 10 | 6 | No property filters, no saved funnels |
| Retention | 10 | 10 | 6 | No property filters, no saved cohorts |
| Segmentation | 10 | 10 | 2 | Biggest gap |
| Trends/charts | 9 | 9 | 7 | Single group-by only |
| User profiles | 8 | 8 | 7 | Good but no behavioral segments |
| Collaboration | 9 | 9 | 1 | No teams, no sharing, no saved reports |
| SDKs | 10 | 10 | 4 | Only 2 languages |
| Data export | 8 | 8 | 2 | Not yet functional |
| Alerts/webhooks | 7 | 8 | 1 | Planned but not built |
| Error tracking | 3 | 2 | 8 | Tally leads — most analytics tools don't do this |
| Self-hosted | 2 | 0 | 10 | Tally's differentiator |
| Price | 3 | 3 | 10 | Free/cheap vs $999+/mo |

---

## 7. Recommended Priority Order

1. **Tests** — Before anything else. Protect what we've built.
2. **Property filters on funnels/retention** — Makes existing features actually useful for real analysis.
3. **Segmentation (saved cohorts)** — "Users who did X" applied to any report.
4. **Data export (CSV)** — Table stakes, easy win.
5. **Webhooks/Slack alerts** — Makes analytics actionable.
6. **Python + Node SDKs** — Opens up to 90% of backends.
7. **Saved reports** — Retention for our own users (meta!).
8. **Team members/roles** — Required for B2B adoption.
9. **User paths/flows** — Hard but high-value differentiator.
10. **Custom dashboards** — Enterprise feature, build when customers ask.

---

## Bottom Line

**Tally covers what 80% of Mixpanel users actually use, self-hosted, for free.** The autocapture and error tracking actually exceed what Amplitude/Mixpanel offer natively.

**The main gaps are:**
- **Segmentation** — the ability to slice any report by user/event properties (this is THE feature that makes Mixpanel Mixpanel)
- **Collaboration** — no teams, saved reports, or sharing
- **Tests** — zero coverage is a deployment risk

The remaining 20% (segmentation, collaboration, more SDKs) is what separates a tool from a product.
