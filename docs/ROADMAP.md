# Roadmap

## Week 1: Foundation + Ingestion
- [ ] Rails 8 new app, PostgreSQL, Tailwind, Solid Queue
- [ ] Migrations: projects, user_profiles, events (partitioned), event_daily_rollups, identity_aliases
- [ ] Models with validations and associations
- [ ] API key generation (pk_ / sk_ prefixed)
- [ ] Ingestion API: POST /track, /batch, /identify, /alias
- [ ] EventIngestionService (core business logic)
- [ ] Rate limiting (Rack::Attack)
- [ ] Idempotency via partial unique index
- [ ] Test with curl

## Week 2: Query Layer + Dashboard
- [ ] RollupService + RollupJob (every 10 min via Solid Queue)
- [ ] Query endpoints: event_counts, top_events, user_timeline
- [ ] Dashboard layout with Tailwind
- [ ] Project CRUD + API key management UI
- [ ] Project dashboard: event trends (Chart.js), top events, key metrics
- [ ] User timeline page
- [ ] Turbo Frames for lazy-loading widgets
- [ ] Date range picker (Stimulus)

## Week 3: SDKs
- [ ] Ruby gem: tally_analytics (zero-dep, Net::HTTP)
- [ ] JS SDK: tally.js (batching, sendBeacon, localStorage identity)
- [ ] Integration test: wire into C-Cube (Vroom), verify events flow
- [ ] SDK documentation

## Week 4: Deploy + Polish
- [ ] Deploy with Kamal 2 (VPS + PostgreSQL)
- [ ] Demo seed data (rake task generating realistic events)
- [ ] README with architecture diagram
- [ ] 2-min Loom walkthrough
- [ ] Portfolio write-up

## Future (if needed)
- Hourly rollups for higher-resolution charts
- Property breakdowns (count by property value)
- Retention grid (did user come back after day 1, 7, 30?)
- Export to CSV
- Webhook on event (e.g. notify Slack on "subscription-cancelled")
- TimescaleDB for automatic partitioning at scale
