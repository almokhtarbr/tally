// Package tally is a zero-dependency Go client for Tally Analytics.
//
// It only uses the standard library. Track() buffers events and a background
// goroutine flushes them in batches; Identify() and Alias() send immediately.
// Call Close() on shutdown to flush what's left.
//
//	c := tally.New(tally.Config{APIKey: "pk_xxx", Endpoint: "https://tally.example.com"})
//	defer c.Close()
//	c.Track("user@example.com", "purchase", map[string]any{"plan": "pro"}, nil)
//	c.Identify("user@example.com", map[string]any{"name": "Jane"})
//	c.Alias("anon_abc123", "user@example.com")
package tally

import (
	"bytes"
	"context"
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"
)

// Config configures a Client. APIKey and Endpoint are required.
type Config struct {
	APIKey        string
	Endpoint      string        // e.g. https://tally.example.com (trailing slash trimmed)
	BatchSize     int           // events per batch, default 50, capped at 100 by the API
	FlushInterval time.Duration // background flush cadence, default 5s
	Timeout       time.Duration // per-request timeout, default 5s
	Logger        *log.Logger   // where transport errors go; nil = log.Default()
	HTTPClient    *http.Client  // override for tests; nil = a client with Timeout
}

type event struct {
	Event          string         `json:"event"`
	UserID         string         `json:"user_id,omitempty"`
	Properties     map[string]any `json:"properties"`
	Timestamp      string         `json:"timestamp"`
	IdempotencyKey string         `json:"idempotency_key,omitempty"`
}

// EventOptions are optional per-Track fields.
type EventOptions struct {
	Timestamp      time.Time
	IdempotencyKey string
}

// Client is safe for concurrent use.
type Client struct {
	cfg    Config
	http   *http.Client
	logger *log.Logger

	mu    sync.Mutex
	queue []event

	stop   chan struct{}
	done   chan struct{}
	closed bool
}

// New starts a Client and its background flush loop.
func New(cfg Config) *Client {
	if cfg.BatchSize <= 0 {
		cfg.BatchSize = 50
	}
	if cfg.FlushInterval <= 0 {
		cfg.FlushInterval = 5 * time.Second
	}
	if cfg.Timeout <= 0 {
		cfg.Timeout = 5 * time.Second
	}
	for len(cfg.Endpoint) > 0 && cfg.Endpoint[len(cfg.Endpoint)-1] == '/' {
		cfg.Endpoint = cfg.Endpoint[:len(cfg.Endpoint)-1]
	}
	logger := cfg.Logger
	if logger == nil {
		logger = log.Default()
	}
	httpClient := cfg.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{Timeout: cfg.Timeout}
	}

	c := &Client{
		cfg:    cfg,
		http:   httpClient,
		logger: logger,
		stop:   make(chan struct{}),
		done:   make(chan struct{}),
	}
	go c.loop()
	return c
}

// Track buffers an event. opts may be nil.
func (c *Client) Track(userID, name string, props map[string]any, opts *EventOptions) {
	if props == nil {
		props = map[string]any{}
	}
	e := event{Event: name, UserID: userID, Properties: props, Timestamp: time.Now().UTC().Format(time.RFC3339)}
	if opts != nil {
		if !opts.Timestamp.IsZero() {
			e.Timestamp = opts.Timestamp.UTC().Format(time.RFC3339)
		}
		e.IdempotencyKey = opts.IdempotencyKey
	}

	c.mu.Lock()
	c.queue = append(c.queue, e)
	full := len(c.queue) >= c.cfg.BatchSize
	c.mu.Unlock()
	if full {
		c.Flush()
	}
}

// Identify sets properties on a user. Sent immediately.
func (c *Client) Identify(userID string, props map[string]any) error {
	if props == nil {
		props = map[string]any{}
	}
	return c.post("/api/v1/identify", map[string]any{"user_id": userID, "properties": props})
}

// Alias links an anonymous id to an identified user. Sent immediately.
func (c *Client) Alias(anonymousID, userID string) error {
	return c.post("/api/v1/alias", map[string]any{"anonymous_id": anonymousID, "user_id": userID})
}

// Flush sends any buffered events now.
func (c *Client) Flush() {
	c.mu.Lock()
	batch := c.queue
	c.queue = nil
	c.mu.Unlock()

	for len(batch) > 0 {
		n := min(len(batch), 100)
		if err := c.post("/api/v1/batch", map[string]any{"events": batch[:n]}); err != nil {
			c.logger.Printf("tally: batch send failed: %v", err)
		}
		batch = batch[n:]
	}
}

// Close flushes and stops the background loop. Safe to call more than once.
func (c *Client) Close() {
	c.mu.Lock()
	if c.closed {
		c.mu.Unlock()
		return
	}
	c.closed = true
	c.mu.Unlock()

	close(c.stop)
	<-c.done
	c.Flush()
}

func (c *Client) loop() {
	defer close(c.done)
	t := time.NewTicker(c.cfg.FlushInterval)
	defer t.Stop()
	for {
		select {
		case <-c.stop:
			return
		case <-t.C:
			c.Flush()
		}
	}
}

func (c *Client) post(path string, body any) error {
	data, err := json.Marshal(body)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), c.cfg.Timeout)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.cfg.Endpoint+path, bytes.NewReader(data))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-API-Key", c.cfg.APIKey)

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		c.logger.Printf("tally: %s returned %d", path, resp.StatusCode)
	}
	return nil
}
