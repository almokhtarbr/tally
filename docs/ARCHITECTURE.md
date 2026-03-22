# Architecture

## 4 Sub-Systems

Tally decomposes into 4 sub-systems, each with different scaling characteristics:

| Sub-system | Nature | Key Challenge |
|---|---|---|
| **Ingestion** (write path) | High-throughput, latency-tolerant | Must never block the host app |
| **Storage** | Time-series, append-only | Fast writes AND analytical reads |
| **Aggregation** | Raw events → pre-computed answers | Write amplification vs read performance |
| **Dashboard** | Read-heavy presentation | Pre-compute vs query live |

**Key insight:** Writes and reads have fundamentally different access patterns. This drives every architecture decision.

---

## Data Model (5 tables)

```
projects
├── api_key (public, write-only)
├── api_secret (private, read-only)
└── name, url, created_at

user_profiles
├── project_id (FK)
├── external_id (the app's user identifier)
├── properties (JSONB)
└── first_seen_at, last_seen_at

events
├── project_id (FK)
├── user_profile_id (FK, nullable)
├── name (e.g. "subscription-update")
├── properties (JSONB)
├── idempotency_key (optional, for dedup)
├── occurred_at
└── PARTITIONED BY MONTH on occurred_at

event_daily_rollups
├── project_id (FK)
├── event_name
├── date
└── count (integer, incremented on each event)

identity_aliases
├── project_id (FK)
├── anonymous_id
├── identified_id (FK → user_profiles)
└── created_at
```

### Why these decisions?

- **JSONB for properties** — Schema flexibility. No migrations when an app adds a new property. GIN-indexable for queries.
- **Monthly partitions on events** — Time-range queries only scan relevant months. `DROP` partition is O(1) vs `DELETE` is O(n) for data retention.
- **Rollup table** — Dashboard reads go from O(n) full scans to O(1) lookups. Trade-off: every event writes twice (raw + rollup).
- **Counter on rollups** — `UPDATE count = count + 1` instead of `COUNT(*)` at read time.
- **Two API keys per project** — Public key can only write events (safe to embed in JS). Secret key can read data (server-side only).

### What changes at scale

| Scale | Change |
|---|---|
| **10x** (~1K events/day) | Rollups become necessary, not just nice-to-have |
| **100x** (~10K events/day) | Add hourly rollups, property-specific rollup tables, consider TimescaleDB |
| **1000x** (~100K events/day) | ClickHouse for columnar storage, Kafka for ingestion buffer, HyperLogLog for approximate uniques |

---

## Ingestion Pipeline

```
Client SDK  →  POST /api/v1/track  →  [Validate + Dedup]  →  INSERT event  →  Upsert user_profile  →  Update rollup
```

### V1: Synchronous

At <100 events/day, async adds complexity with zero benefit. A single INSERT takes <5ms. The API returns **202 Accepted** regardless — so migrating to async later is a backend-only change with zero SDK impact.

### Future: Async with Redis buffer

At 10K+/day: buffer events with `LPUSH` into Redis, a worker drains in batches of 100 using multi-row INSERT.

### Idempotency

- Optional `idempotency_key` per event (client-generated UUID)
- Partial unique index: `WHERE idempotency_key IS NOT NULL` — no index bloat for events without keys
- Duplicate events silently ignored (upsert)

---

## Identity Resolution

```
Anonymous visitor (UUID in localStorage)
  → identify("user@email.com")
    → alias record created
      → background job re-links old anonymous events
```

1. JS SDK generates `anon_xxxx` UUID, stored in localStorage (no cookies = simpler privacy)
2. On `identify()`, creates alias row + upserts user profile
3. Background job backfills: `UPDATE events SET user_profile_id = X WHERE user_profile_id = old_anon_profile_id`
4. Eventual consistency — there's a short window where anonymous events aren't linked yet

---

## Dashboard

Built with **Hotwire/Turbo + Stimulus + Chart.js** (not a SPA).

- **Turbo Frames** for lazy-loading each widget independently (parallel loads)
- **Chart.js** via Stimulus controller for event timelines
- **Date range picker** updates all frames simultaneously

Pages:
1. Project list (all monitored apps)
2. Project dashboard (event trends, top events, key metrics)
3. User timeline (what did a specific user do?)

---

## Tech Stack

| Layer | Choice | Why |
|---|---|---|
| Framework | Rails 8 | Convention over configuration, Solid Queue built-in |
| Database | PostgreSQL | JSONB, partitioning, battle-tested |
| Background jobs | Solid Queue | Ships with Rails 8, no Redis dependency |
| Frontend | Hotwire/Turbo + Stimulus | Server-rendered, minimal JS, modern Rails way |
| Charts | Chart.js | Lightweight, Stimulus-friendly |
| CSS | Tailwind CSS | Utility-first, fast to prototype |
| Deploy | Kamal 2 + Thruster | DHH way — Docker-based, zero-downtime, any VPS |
