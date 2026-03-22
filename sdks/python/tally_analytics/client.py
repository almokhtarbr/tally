"""Tally Analytics Python SDK client.

Zero-dependency. Uses only stdlib (urllib, json, threading).
Supports batching, background flushing, and graceful shutdown.

Usage:
    from tally_analytics import TallyAnalytics

    tally = TallyAnalytics(api_key="pk_xxx", endpoint="https://tally.example.com")
    tally.track("user@example.com", "purchase", properties={"plan": "pro", "amount": 99})
    tally.identify("user@example.com", properties={"name": "Jane", "plan": "pro"})
    tally.alias("anon_abc123", "user@example.com")
    tally.shutdown()  # Flush remaining events
"""

import json
import logging
import threading
import time
from datetime import datetime, timezone
from urllib.request import Request, urlopen
from urllib.error import URLError

logger = logging.getLogger("tally_analytics")


class TallyAnalytics:
    """Tally Analytics client with batching and background flush."""

    def __init__(self, api_key, endpoint, batch_size=50, flush_interval=5.0, timeout=5):
        self.api_key = api_key
        self.endpoint = endpoint.rstrip("/")
        self.batch_size = batch_size
        self.flush_interval = flush_interval
        self.timeout = timeout

        self._queue = []
        self._lock = threading.Lock()
        self._running = True

        self._flush_thread = threading.Thread(target=self._flush_loop, daemon=True)
        self._flush_thread.start()

    def track(self, user_id, event_name, properties=None, timestamp=None, idempotency_key=None):
        """Track an event."""
        payload = {
            "event": event_name,
            "user_id": user_id,
            "properties": properties or {},
            "timestamp": timestamp or datetime.now(timezone.utc).isoformat(),
        }
        if idempotency_key:
            payload["idempotency_key"] = idempotency_key

        with self._lock:
            self._queue.append(payload)
            if len(self._queue) >= self.batch_size:
                self._flush_locked()

    def identify(self, user_id, properties=None):
        """Identify a user and set properties."""
        self._post("/api/v1/identify", {
            "user_id": user_id,
            "properties": properties or {},
        })

    def alias(self, anonymous_id, user_id):
        """Link an anonymous ID to an identified user."""
        self._post("/api/v1/alias", {
            "anonymous_id": anonymous_id,
            "user_id": user_id,
        })

    def flush(self):
        """Flush all queued events immediately."""
        with self._lock:
            self._flush_locked()

    def shutdown(self):
        """Flush remaining events and stop background thread."""
        self._running = False
        self.flush()
        self._flush_thread.join(timeout=10)

    def _flush_loop(self):
        while self._running:
            time.sleep(self.flush_interval)
            with self._lock:
                if self._queue:
                    self._flush_locked()

    def _flush_locked(self):
        """Must be called with self._lock held."""
        if not self._queue:
            return

        events = self._queue[:100]  # API limit
        self._queue = self._queue[100:]

        threading.Thread(
            target=self._send_batch,
            args=(events,),
            daemon=True,
        ).start()

    def _send_batch(self, events):
        try:
            self._post("/api/v1/batch", {"events": events})
        except Exception as e:
            logger.warning("Tally batch send failed: %s", e)

    def _post(self, path, body):
        url = f"{self.endpoint}{path}"
        data = json.dumps(body).encode("utf-8")

        req = Request(url, data=data, method="POST")
        req.add_header("Content-Type", "application/json")
        req.add_header("X-API-Key", self.api_key)

        try:
            resp = urlopen(req, timeout=self.timeout)
            if resp.status >= 400:
                logger.warning("Tally API %s returned %d", path, resp.status)
        except URLError as e:
            logger.warning("Tally API %s failed: %s", path, e)
        except Exception as e:
            logger.warning("Tally API %s error: %s", path, e)
