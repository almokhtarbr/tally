# Tally Analytics Node.js SDK

Zero-dependency Node.js SDK for [Tally Analytics](https://github.com/your-org/tally). Uses native `fetch` (Node 18+).

## Install

```bash
npm install tally-analytics
```

## Usage

```javascript
const { TallyAnalytics } = require('tally-analytics');

const tally = new TallyAnalytics({
  apiKey: 'pk_your_key',
  endpoint: 'https://tally.example.com',
});

// Track events (batched automatically)
tally.track('user@example.com', 'purchase', { plan: 'pro', amount: 99 });

// Identify users
await tally.identify('user@example.com', { name: 'Jane', company: 'Acme' });

// Link anonymous to identified
await tally.alias('anon_abc123', 'user@example.com');

// Graceful shutdown
await tally.shutdown();
```

## Features

- Zero dependencies (native `fetch`)
- Automatic batching (50 events, flush every 5s)
- TypeScript definitions included
- Graceful shutdown with `shutdown()`
