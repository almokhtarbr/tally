# Interview Talking Points

These are the system design trade-offs worth discussing when presenting Tally.

---

## 1. "Why not just use Mixpanel/PostHog?"

"We were paying $999/month for 10 events. I decomposed what we actually needed, built it in 4 weeks, and saved $12K/year. The interesting part isn't the code — it's knowing when NOT to use a vendor."

## 2. "Why synchronous ingestion? Shouldn't analytics be async?"

"At our scale (<100 events/day), async adds a Redis dependency and worker complexity for zero benefit. A single INSERT is <5ms. But the API returns 202 Accepted, so the contract is already async — migrating to a Redis buffer later is a backend-only change. Zero SDK impact."

## 3. "Why rollup tables instead of materialized views?"

"Materialized views do a full refresh — they recompute everything. Rollups are incremental: each event does `UPDATE count = count + 1`. The trade-off is write amplification (every event writes twice), but dashboard reads go from O(n) scans to O(1) lookups. At our scale, that's the right trade."

## 4. "Why partition the events table by month?"

"Three reasons: (1) Partition pruning — a query for March only scans the March partition, not the whole table. (2) Data retention — DROP a partition is O(1) vs DELETE WHERE is O(n) and leaves bloat. (3) Vacuuming — smaller partitions mean faster maintenance."

## 5. "Why JSONB for event properties?"

"Schema flexibility. When an app adds a new property, there's no migration. JSONB is GIN-indexable for querying. The trade-off is you lose column-level type safety and columnar compression. At 1000x scale, you'd extract high-cardinality columns into dedicated fields. But at our scale, JSONB is the right call."

## 6. "Why zero-dependency SDKs?"

"Analytics code runs inside other people's apps. If my gem depends on Faraday 2.x and the host app uses Faraday 1.x, that's a production incident that has nothing to do with analytics. Net::HTTP is in Ruby's stdlib — it's always there, it never conflicts."

## 7. "What would you change at 1000x scale?"

"Three things: (1) Replace PostgreSQL events table with ClickHouse — columnar storage is 10-100x faster for analytical queries. (2) Add Kafka between the API and storage — buffer spikes, guarantee delivery, enable multiple consumers. (3) Use HyperLogLog for approximate unique counts instead of exact COUNT(DISTINCT)."

## 8. "Why Hotwire instead of React/a SPA?"

"The dashboard is read-heavy with simple interactions. Turbo Frames give me lazy-loading and partial page updates without shipping a JS framework. It also demonstrates range — the host app (C-Cube) is Ember, this is server-rendered Rails. Different tools for different problems."

## 9. "How does identity resolution work?"

"The JS SDK generates an anonymous UUID in localStorage. When the app calls identify(), we create an alias record and a background job backfills old events. There's an eventual consistency window — anonymous events aren't linked until the job runs. For a real-time product like Mixpanel, they solve this with a streaming pipeline. For our scale, a 10-minute job is fine."

## 10. "What's the hardest part of this project?"

"Honestly? Scope discipline. It's tempting to add funnels, cohorts, retention grids. But the whole point was that we only needed 20% of Mixpanel. Shipping the right 20% and stopping is harder than building 100%."
