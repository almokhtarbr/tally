# API Reference

## Authentication

Two keys per project, different permissions:

| Key | Header | Can |
|---|---|---|
| API Key (public) | `X-API-Key: pk_abc123` | Write events, identify users |
| API Secret (private) | `Authorization: Bearer sk_abc123` | Read/query data |

The API Key is safe to embed in client-side JS. It can only write, never read.

---

## Write Endpoints (API Key auth)

### POST /api/v1/track

Track a single event.

```json
{
  "event": "subscription-update",
  "user_id": "user@email.com",
  "properties": {
    "plan": "premium",
    "mrr": 99
  },
  "timestamp": "2026-03-15T10:30:00Z",
  "idempotency_key": "uuid-optional"
}
```

- `event` — required, string
- `user_id` — optional, string (your app's user identifier)
- `properties` — optional, object (any key/value pairs)
- `timestamp` — optional, ISO 8601 (defaults to server time)
- `idempotency_key` — optional, string (for dedup)

**Response:** `202 Accepted`
```json
{ "status": "accepted" }
```

---

### POST /api/v1/batch

Track multiple events in one request. Same fields as `/track`, wrapped in an array.

```json
{
  "events": [
    { "event": "page-view", "user_id": "user@email.com", "properties": { "page": "/quotes" } },
    { "event": "quote-created", "user_id": "user@email.com", "properties": { "value": 5000 } }
  ]
}
```

**Response:** `202 Accepted`
```json
{ "status": "accepted", "received": 2 }
```

Max 100 events per batch.

---

### POST /api/v1/identify

Set or update properties on a user profile.

```json
{
  "user_id": "user@email.com",
  "properties": {
    "name": "Jane Doe",
    "plan": "premium",
    "company": "Acme Corp",
    "role": "admin"
  }
}
```

Properties are merged (not replaced). To remove a property, set it to `null`.

**Response:** `202 Accepted`
```json
{ "status": "accepted" }
```

---

### POST /api/v1/alias

Link an anonymous ID to an identified user.

```json
{
  "anonymous_id": "anon_abc123",
  "user_id": "user@email.com"
}
```

This triggers a background job to re-link all events from the anonymous profile to the identified user.

**Response:** `202 Accepted`
```json
{ "status": "accepted" }
```

---

## Read Endpoints (API Secret auth)

### GET /api/v1/queries/event_counts

Time series of event counts.

**Params:**
- `event` — required, event name
- `from` — required, ISO 8601 date
- `to` — required, ISO 8601 date
- `granularity` — optional, `day` (default) or `month`

**Response:**
```json
{
  "event": "subscription-update",
  "granularity": "day",
  "data": [
    { "date": "2026-03-01", "count": 12 },
    { "date": "2026-03-02", "count": 8 },
    { "date": "2026-03-03", "count": 15 }
  ]
}
```

---

### GET /api/v1/queries/top_events

Leaderboard of most frequent events.

**Params:**
- `from` — required, ISO 8601 date
- `to` — required, ISO 8601 date
- `limit` — optional, default 10

**Response:**
```json
{
  "data": [
    { "event": "page-view", "count": 1240 },
    { "event": "quote-created", "count": 89 },
    { "event": "subscription-update", "count": 34 }
  ]
}
```

---

### GET /api/v1/queries/user_timeline

Activity history for a specific user.

**Params:**
- `user_id` — required, the user's external ID
- `from` — optional, ISO 8601 date
- `to` — optional, ISO 8601 date
- `limit` — optional, default 50

**Response:**
```json
{
  "user_id": "user@email.com",
  "data": [
    { "event": "subscription-update", "properties": { "plan": "premium" }, "timestamp": "2026-03-15T10:30:00Z" },
    { "event": "quote-created", "properties": { "value": 5000 }, "timestamp": "2026-03-15T09:15:00Z" }
  ]
}
```

---

## Error Responses

All errors return a consistent format:

```json
{ "error": "description of what went wrong" }
```

| Status | Meaning |
|---|---|
| 400 | Bad request (missing required fields) |
| 401 | Invalid or missing API key/secret |
| 422 | Validation error (e.g. batch > 100 events) |
| 429 | Rate limited |
