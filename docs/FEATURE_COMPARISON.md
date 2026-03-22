# Feature Comparison — Tally vs Competitors

Last updated: March 16, 2026

---

## What We Have vs What They Have

| Feature | Amplitude | PostHog | Mixpanel | Tally |
|---|---|---|---|---|
| **Autocapture (clicks, forms, etc.)** | Yes | Yes | No | Yes |
| **Pageview tracking** | Yes | Yes | Yes | Yes |
| **Session tracking (start/end/duration)** | Yes | Yes | Yes | Yes |
| **User identification** | Yes | Yes | Yes | Yes |
| **Identity resolution (anon→user)** | Yes | Yes | Yes | Yes |
| **Real-time live feed** | Yes | Yes | Yes | Yes |
| **Top pages / events** | Yes | Yes | Yes | Yes |
| **Trend charts (time series)** | Yes | Yes | Yes | Yes |
| **JS SDK (autocapture, SPA support)** | Yes | Yes | Yes | Yes |
| **Server-side SDK (Ruby)** | Yes | Yes | Yes | Yes |
| **Rage click detection** | No | Yes | No | Yes |
| **Dead click detection** | No | Yes | No | Yes |
| **JS error tracking** | No | Yes | No | Yes |
| **Scroll depth tracking** | No | Yes | No | Yes |
| **Form interaction tracking** | Yes | Yes | No | Yes |
| **Bounce rate** | Yes | Yes | No | Yes |
| **Referrer tracking** | Yes | Yes | No | Yes |
| **UTM parameter capture** | Yes | Yes | Yes | Yes |
| **Device/browser/OS detection** | Yes | Yes | Yes | Yes |
| **Outbound click tracking** | No | Yes | No | Yes |
| **API key separation (public/private)** | Yes | Yes | Yes | Yes |
| **Real-time dashboard (WebSocket)** | Yes | Yes | Yes | Yes |
| **Percentage trend comparisons** | Yes | Yes | Yes | Yes |

---

## What We're Missing

### Must-Have for a Real Product (Priority 1)

| Feature | What it does | Why it matters | Difficulty |
|---|---|---|---|
| **Funnels** | Show drop-off: 100 signup → 60 create project → 10 upgrade | #1 reason people pay for analytics. Answers "where am I losing users?" | Medium |
| **Retention** | Did users come back after day 1, 7, 30? | #2 reason. Answers "is my product sticky?" | Medium |
| **Data export / CSV** | Download events, users, reports | People want their data out. Table stakes. | Easy |
| **Webhooks / alerts** | Notify Slack/email when specific event happens | "Tell me when someone cancels" — actionable | Easy |

### Nice to Have (Priority 2)

| Feature | What it does | Why it matters | Difficulty |
|---|---|---|---|
| **User paths / flows** | Visualize A→B→C navigation patterns | Answers "how do users actually move through my app?" | Hard |
| **Cohorts** | Group users by behavior (signed up in Jan, used feature X) | Segment analysis, targeted messaging | Medium |
| **Multiple dashboards** | Create custom dashboard layouts per team/use case | Enterprise expectation | Medium |
| **Team members / roles** | Multiple logins with viewer/admin permissions | Required for any team >1 person | Medium |
| **Saved reports / bookmarks** | Save a specific query to revisit later | Power user feature | Easy |
| **Email reports** | Weekly digest email with key metrics | "Send me a summary every Monday" | Easy |

### Don't Build (Too Complex, Not Our Differentiator)

| Feature | Why not |
|---|---|
| **Session replay** | PostHog spent years building this. Requires recording DOM, massive storage, video playback UI. Whole product by itself. |
| **Feature flags** | Separate product category (LaunchDarkly, Statsig). Adds complexity without analytics value. |
| **A/B testing** | Needs statistical significance engine, experiment management, variant serving. Years of work. |
| **Surveys** | Different product. Typeform/Hotjar territory. |
| **Data warehouse / SQL access** | Requires query engine, security sandboxing. PostHog uses ClickHouse for this. |
| **AI / natural language queries** | Cool demo, massive engineering effort, not a differentiator at MVP stage. |

---

## What Makes Tally Different

We're not trying to clone Amplitude or PostHog. They have 100+ engineers and years of development. Our angle:

1. **Simplicity** — Install a script tag, get everything. No configuration, no event planning, no data model design.
2. **Self-hosted** — Your data stays on your server. No vendor lock-in. No "we changed our pricing" surprises.
3. **Affordable** — Free for small apps, $29/mo for serious usage. Mixpanel charges $999/mo for the same volume.
4. **Developer-first** — Zero-dependency SDKs, clean API, works with any framework. Not a marketing tool pretending to be technical.

---

## Roadmap Priority

### Next up: Funnels
The single most valuable feature we're missing. With funnels, Tally goes from "event logger" to "product analytics tool."

Example funnel:
```
signup (100 users)
  → created-project (60 users, 60% conversion)
    → created-quote (25 users, 42% conversion)
      → sent-invoice (10 users, 40% conversion)
        → subscription-upgraded (3 users, 30% conversion)
```

This answers "where exactly am I losing users?" — the most important question in SaaS.

### After funnels: Retention
```
        Day 1    Day 7    Day 30
Week 1:  85%      45%      20%
Week 2:  82%      48%      22%
Week 3:  90%      52%      25%  ← something improved
```

This answers "is my product getting stickier?" — the second most important question.

### After retention: Export + Webhooks
Low effort, high value. People want their data and they want notifications.
