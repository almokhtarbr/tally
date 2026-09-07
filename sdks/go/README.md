# Tally Analytics — Go SDK

Zero-dependency (standard library only). Buffers events and flushes them in
batches on a background goroutine; `Identify` and `Alias` send immediately.

## Install

```bash
go get github.com/almokhtarbr/tally/sdks/go
```

```go
import tally "github.com/almokhtarbr/tally/sdks/go"
```

## Usage

```go
c := tally.New(tally.Config{
    APIKey:   "pk_your_key",
    Endpoint: "https://tally.yourdomain.com",
})
defer c.Close() // flushes buffered events

c.Track("user@example.com", "purchase", map[string]any{"plan": "pro", "amount": 99}, nil)

c.Track("user@example.com", "signup", nil, &tally.EventOptions{
    IdempotencyKey: "signup-42",
})

c.Identify("user@example.com", map[string]any{"name": "Jane", "plan": "pro"})
c.Alias("anon_abc123", "user@example.com")

c.Flush() // send now, without closing
```

## Config

| Field | Default | |
|---|---|---|
| `APIKey` | — | required, the project's `pk_…` key |
| `Endpoint` | — | required, your Tally URL (trailing slash trimmed) |
| `BatchSize` | 50 | events per batch (API caps at 100) |
| `FlushInterval` | 5s | background flush cadence |
| `Timeout` | 5s | per-request timeout |
| `Logger` | `log.Default()` | transport errors go here |
| `HTTPClient` | — | override for tests |

The client is safe for concurrent use. Transport failures are logged, never
returned from `Track`.
