/**
 * Tally Analytics Node.js SDK
 *
 * Zero-dependency. Uses native fetch (Node 18+).
 * Supports batching, background flushing, and graceful shutdown.
 *
 * Usage:
 *   const { TallyAnalytics } = require('tally-analytics');
 *   const tally = new TallyAnalytics({ apiKey: 'pk_xxx', endpoint: 'https://tally.example.com' });
 *   tally.track('user@example.com', 'purchase', { plan: 'pro' });
 *   await tally.shutdown();
 */

class TallyAnalytics {
  /**
   * @param {Object} options
   * @param {string} options.apiKey - Your project's public API key (pk_...)
   * @param {string} options.endpoint - Your Tally instance URL
   * @param {number} [options.batchSize=50] - Max events per batch
   * @param {number} [options.flushInterval=5000] - Flush interval in ms
   * @param {number} [options.timeout=5000] - HTTP timeout in ms
   */
  constructor({ apiKey, endpoint, batchSize = 50, flushInterval = 5000, timeout = 5000 }) {
    this.apiKey = apiKey;
    this.endpoint = endpoint.replace(/\/+$/, '');
    this.batchSize = batchSize;
    this.timeout = timeout;
    this._queue = [];
    this._timer = setInterval(() => this._flush(), flushInterval);
  }

  /**
   * Track an event.
   * @param {string} userId
   * @param {string} eventName
   * @param {Object} [properties={}]
   * @param {Object} [options={}]
   * @param {string} [options.timestamp]
   * @param {string} [options.idempotencyKey]
   */
  track(userId, eventName, properties = {}, options = {}) {
    const payload = {
      event: eventName,
      user_id: userId,
      properties,
      timestamp: options.timestamp || new Date().toISOString(),
    };
    if (options.idempotencyKey) {
      payload.idempotency_key = options.idempotencyKey;
    }
    this._queue.push(payload);
    if (this._queue.length >= this.batchSize) {
      this._flush();
    }
  }

  /**
   * Identify a user and set properties.
   * @param {string} userId
   * @param {Object} [properties={}]
   * @returns {Promise<void>}
   */
  async identify(userId, properties = {}) {
    await this._post('/api/v1/identify', { user_id: userId, properties });
  }

  /**
   * Link an anonymous ID to an identified user.
   * @param {string} anonymousId
   * @param {string} userId
   * @returns {Promise<void>}
   */
  async alias(anonymousId, userId) {
    await this._post('/api/v1/alias', { anonymous_id: anonymousId, user_id: userId });
  }

  /**
   * Flush all queued events immediately.
   * @returns {Promise<void>}
   */
  async flush() {
    await this._flush();
  }

  /**
   * Flush remaining events and stop background timer.
   * @returns {Promise<void>}
   */
  async shutdown() {
    clearInterval(this._timer);
    await this._flush();
  }

  async _flush() {
    if (this._queue.length === 0) return;

    const events = this._queue.splice(0, 100); // API limit
    try {
      await this._post('/api/v1/batch', { events });
    } catch (err) {
      console.warn('[TallyAnalytics] Batch send failed:', err.message);
    }
  }

  async _post(path, body) {
    const url = `${this.endpoint}${path}`;
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), this.timeout);

      const resp = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': this.apiKey,
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!resp.ok) {
        console.warn(`[TallyAnalytics] ${path} returned ${resp.status}`);
      }
    } catch (err) {
      if (err.name !== 'AbortError') {
        console.warn(`[TallyAnalytics] ${path} failed:`, err.message);
      }
    }
  }
}

module.exports = { TallyAnalytics };
