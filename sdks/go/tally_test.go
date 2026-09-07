package tally

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"
)

type capture struct {
	mu   sync.Mutex
	reqs []recorded
}

type recorded struct {
	path   string
	apiKey string
	body   map[string]any
}

func (c *capture) handler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		raw, _ := io.ReadAll(r.Body)
		var body map[string]any
		_ = json.Unmarshal(raw, &body)
		c.mu.Lock()
		c.reqs = append(c.reqs, recorded{r.URL.Path, r.Header.Get("X-API-Key"), body})
		c.mu.Unlock()
		w.WriteHeader(http.StatusAccepted)
	}
}

func (c *capture) get() []recorded {
	c.mu.Lock()
	defer c.mu.Unlock()
	return append([]recorded(nil), c.reqs...)
}

func newTestClient(t *testing.T, url string) *Client {
	t.Helper()
	return New(Config{
		APIKey:        "pk_test",
		Endpoint:      url + "/", // trailing slash should be trimmed
		BatchSize:     3,
		FlushInterval: time.Hour, // never fires; we flush explicitly
	})
}

func TestTrackBatchesAndFlushes(t *testing.T) {
	cap := &capture{}
	srv := httptest.NewServer(cap.handler())
	defer srv.Close()

	c := newTestClient(t, srv.URL)
	defer c.Close()

	c.Track("u1", "signup", nil, nil)
	c.Track("u2", "signup", map[string]any{"plan": "pro"}, nil)
	if len(cap.get()) != 0 {
		t.Fatalf("expected no request before the batch is full or flushed")
	}

	c.Flush()

	reqs := cap.get()
	if len(reqs) != 1 || reqs[0].path != "/api/v1/batch" {
		t.Fatalf("expected one /api/v1/batch request, got %+v", reqs)
	}
	if reqs[0].apiKey != "pk_test" {
		t.Fatalf("X-API-Key not set: %q", reqs[0].apiKey)
	}
	events, _ := reqs[0].body["events"].([]any)
	if len(events) != 2 {
		t.Fatalf("expected 2 events in the batch, got %d", len(events))
	}
}

func TestTrackAutoFlushesAtBatchSize(t *testing.T) {
	cap := &capture{}
	srv := httptest.NewServer(cap.handler())
	defer srv.Close()

	c := newTestClient(t, srv.URL)
	defer c.Close()

	for i := 0; i < 3; i++ {
		c.Track("u", "e", nil, nil)
	}
	// give the async flush a moment
	time.Sleep(50 * time.Millisecond)

	if got := len(cap.get()); got != 1 {
		t.Fatalf("expected an automatic flush at BatchSize=3, got %d requests", got)
	}
}

func TestIdentifyAndAliasSendImmediately(t *testing.T) {
	cap := &capture{}
	srv := httptest.NewServer(cap.handler())
	defer srv.Close()

	c := newTestClient(t, srv.URL)
	defer c.Close()

	if err := c.Identify("u1", map[string]any{"name": "Jane"}); err != nil {
		t.Fatal(err)
	}
	if err := c.Alias("anon_1", "u1"); err != nil {
		t.Fatal(err)
	}

	reqs := cap.get()
	if len(reqs) != 2 || reqs[0].path != "/api/v1/identify" || reqs[1].path != "/api/v1/alias" {
		t.Fatalf("unexpected requests: %+v", reqs)
	}
	if reqs[1].body["anonymous_id"] != "anon_1" {
		t.Fatalf("alias body wrong: %+v", reqs[1].body)
	}
}

func TestCloseFlushesRemaining(t *testing.T) {
	cap := &capture{}
	srv := httptest.NewServer(cap.handler())
	defer srv.Close()

	c := newTestClient(t, srv.URL)
	c.Track("u", "e", nil, nil)
	c.Close()
	c.Close() // idempotent

	if got := len(cap.get()); got != 1 {
		t.Fatalf("expected Close to flush the buffered event, got %d requests", got)
	}
}
