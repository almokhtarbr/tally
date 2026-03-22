# Why Tally Exists

## The Problem

Product analytics tools (Mixpanel, Amplitude, PostHog) charge $500-2000+/month for features most apps never use. A typical SaaS app tracks 10-20 events and a handful of user properties. That's it. You don't need funnels, cohort analysis, A/B testing, or session replay.

You're paying for a warehouse to store a backpack.

## The Real-World Case

C-Cube (a project management SaaS) pays Mixpanel $999+/month to track:
- ~10 custom events (new user, subscription update, quote created, etc.)
- ~5 user properties (plan, role, tenant, etc.)

That's $12,000/year for something a single PostgreSQL table could handle.

## What Tally Is

Tally is a **self-hosted product analytics service** for SaaS apps. It answers one question: **what are users doing inside my app?**

It tracks:
- Named events with properties ("user created a quote", "user upgraded to premium")
- User profiles with properties (plan, role, company)
- Event trends over time (are signups going up or down?)
- Per-user activity timelines (what did this specific user do?)

That's it. No funnels. No cohorts. No A/B testing. Just the 20% of Mixpanel that covers 100% of what most apps actually use.

## What Tally Is NOT

- **Not web analytics** — Google Analytics and Plausible track page views, referrers, bounce rates. Tally tracks what happens after a user logs in.
- **Not a Mixpanel clone** — Tally deliberately excludes features that add complexity without value for small-to-mid SaaS apps.
- **Not tied to one app** — Any app can create a project, get API keys, and start sending events. Vroom, your side project, your client's app — all of them.

## Design Principles

1. **Multi-tenant by design** — Each monitored app is a "project" with its own API keys. One Tally instance serves many apps.
2. **Never block the host app** — SDKs are fire-and-forget. A slow or down Tally instance must never affect the apps sending events.
3. **Simple until proven otherwise** — Start synchronous, add async when the numbers demand it. Start with daily rollups, add hourly when needed.
4. **Zero-dependency SDKs** — The Ruby gem uses only stdlib. The JS snippet is ~2KB. Analytics code runs inside other people's apps — dependency conflicts are a real production risk.
