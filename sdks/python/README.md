# Tally Analytics Python SDK

Zero-dependency Python SDK for [Tally Analytics](https://github.com/your-org/tally).

## Install

```bash
pip install tally-analytics
```

## Usage

```python
from tally_analytics import TallyAnalytics

tally = TallyAnalytics(
    api_key="pk_your_key",
    endpoint="https://tally.example.com"
)

# Track events (batched automatically)
tally.track("user@example.com", "purchase", properties={"plan": "pro", "amount": 99})

# Identify users
tally.identify("user@example.com", properties={"name": "Jane", "company": "Acme"})

# Link anonymous to identified
tally.alias("anon_abc123", "user@example.com")

# Flush on shutdown
tally.shutdown()
```

## Features

- Zero dependencies (stdlib only)
- Automatic batching (50 events, flush every 5s)
- Background thread for non-blocking sends
- Graceful shutdown with `shutdown()`
