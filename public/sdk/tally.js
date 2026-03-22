(function() {
  "use strict";

  var queue = [];
  var config = { apiKey: null, endpoint: "", autotrack: true };
  var FLUSH_INTERVAL = 5000;
  var MAX_BATCH = 100;
  var KEY_ANON = "tally_aid";
  var KEY_USER = "tally_uid";
  var KEY_SESSION = "tally_sess";
  var lastClickTime = 0;
  var lastClickTarget = null;
  var rageCount = 0;
  var RAGE_THRESHOLD = 3;
  var RAGE_WINDOW = 1500;
  var maxScroll = 0;
  var breadcrumbs = [];
  var MAX_BREADCRUMBS = 20;

  function pushBreadcrumb(type, data) {
    breadcrumbs.push({ type: type, data: data, time: new Date().toISOString() });
    if (breadcrumbs.length > MAX_BREADCRUMBS) breadcrumbs.shift();
  }

  function getBreadcrumbsJSON() {
    var s = JSON.stringify(breadcrumbs);
    return s.length > 4096 ? s.slice(0, 4096) : s;
  }

  // ==== IDENTITY (localStorage — survives refresh, tabs, browser restart) ====

  function getAnonId() {
    try {
      var id = localStorage.getItem(KEY_ANON);
      if (!id) { id = "anon_" + crypto.randomUUID(); localStorage.setItem(KEY_ANON, id); }
      return id;
    } catch(e) { return "anon_unknown"; }
  }

  function getUserId() {
    try { return localStorage.getItem(KEY_USER) || null; } catch(e) { return null; }
  }

  function setUserId(id) {
    try { if (id) localStorage.setItem(KEY_USER, id); else localStorage.removeItem(KEY_USER); } catch(e) {}
  }

  // ==== SESSIONS (sessionStorage — survives refresh within same tab) ====

  function getSession() {
    try {
      var raw = sessionStorage.getItem(KEY_SESSION);
      if (raw) {
        var s = JSON.parse(raw);
        if (Date.now() - s.la < 30 * 60 * 1000) { s.la = Date.now(); sessionStorage.setItem(KEY_SESSION, JSON.stringify(s)); return s; }
      }
      var sess = { id: crypto.randomUUID(), st: Date.now(), la: Date.now(), pc: 0, ref: document.referrer || null, lp: window.location.pathname };
      sessionStorage.setItem(KEY_SESSION, JSON.stringify(sess));
      return sess;
    } catch(e) { return { id: "unknown", pc: 0 }; }
  }

  function bumpSession() {
    try { var s = getSession(); s.pc++; s.la = Date.now(); sessionStorage.setItem(KEY_SESSION, JSON.stringify(s)); return s; }
    catch(e) { return { id: "unknown", pc: 0 }; }
  }

  // ==== HELPERS ====

  function utmParams() {
    var p = {}, s = window.location.search;
    ["utm_source","utm_medium","utm_campaign","utm_term","utm_content"].forEach(function(k) {
      var m = s.match(new RegExp("[?&]" + k + "=([^&]*)"));
      if (m) p[k] = decodeURIComponent(m[1]);
    });
    return p;
  }

  function deviceInfo() {
    var ua = navigator.userAgent;
    var mobile = /Mobi|Android|iPhone|iPad/i.test(ua);
    var browser = /Firefox/i.test(ua) ? "Firefox" : /Edg/i.test(ua) ? "Edge" : /Chrome/i.test(ua) ? "Chrome" : /Safari/i.test(ua) ? "Safari" : "Other";
    var os = /Windows/i.test(ua) ? "Windows" : /Mac/i.test(ua) ? "macOS" : /Linux/i.test(ua) ? "Linux" : /Android/i.test(ua) ? "Android" : /iPhone|iPad/i.test(ua) ? "iOS" : "Other";
    return {
      screen: screen.width + "x" + screen.height,
      viewport: window.innerWidth + "x" + window.innerHeight,
      language: navigator.language,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      browser: browser,
      os: os,
      device_type: mobile ? "mobile" : "desktop",
      touch: "ontouchstart" in window
    };
  }

  // Get a human-readable selector for an element (like PostHog does)
  function getSelector(el) {
    if (!el || !el.tagName) return "";
    var parts = [];
    var tag = el.tagName.toLowerCase();

    // id
    if (el.id) return tag + "#" + el.id;

    // classes (max 3)
    if (el.className && typeof el.className === "string") {
      var cls = el.className.trim().split(/\s+/).filter(function(c) { return c && c.length < 40; }).slice(0, 3);
      if (cls.length) return tag + "." + cls.join(".");
    }

    // data-testid or data-action or name
    if (el.getAttribute("data-testid")) return tag + "[data-testid='" + el.getAttribute("data-testid") + "']";
    if (el.getAttribute("name")) return tag + "[name='" + el.getAttribute("name") + "']";

    return tag;
  }

  // Get readable text from element (max 120 chars, no sensitive data)
  function getElText(el) {
    // Don't capture text from inputs (could be passwords, emails etc)
    if (el.tagName === "INPUT" || el.tagName === "TEXTAREA" || el.tagName === "SELECT") return "";
    var t = (el.textContent || el.innerText || "").trim().replace(/\s+/g, " ");
    return t.slice(0, 120);
  }

  // ==== QUEUE + FLUSH ====

  function enqueue(name, props) {
    var sess = getSession();
    queue.push({
      event: name,
      user_id: getUserId(),
      anonymous_id: getAnonId(),
      properties: Object.assign({
        url: window.location.href,
        path: window.location.pathname,
        title: document.title,
        referrer: document.referrer || null,
        session_id: sess.id
      }, props || {}),
      timestamp: new Date().toISOString()
    });
  }

  function flush() {
    if (!queue.length || !config.apiKey) return;
    var batch = queue.splice(0, MAX_BATCH);
    post(config.endpoint + "/api/v1/batch", { events: batch, api_key: config.apiKey });
  }

  function post(url, body) {
    try {
      fetch(url, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body), credentials: "omit", mode: "cors", keepalive: true }).catch(function(){});
    } catch(e) {}
  }

  // ==== AUTOCAPTURE ====

  function setupAutocapture() {

    // --- 1. PAGEVIEW (auto on load + SPA nav) ---
    autoPageview();
    if (getSession().pc <= 1) autoSessionStart();

    var lastPath = window.location.pathname;
    var _push = history.pushState, _replace = history.replaceState;
    history.pushState = function() { _push.apply(this, arguments); checkNav(); };
    history.replaceState = function() { _replace.apply(this, arguments); checkNav(); };
    window.addEventListener("popstate", checkNav);
    function checkNav() { var p = window.location.pathname; if (p !== lastPath) { lastPath = p; autoPageview(); } }

    // --- 2. CLICK (every click, like Amplitude/PostHog autocapture) ---
    document.addEventListener("click", function(e) {
      var target = e.target.closest("a, button, [role='button'], input[type='submit'], input[type='button'], [data-track]");
      if (!target) {
        // Dead click — clicked on nothing interactive
        enqueue("$dead_click", {
          tag: e.target.tagName.toLowerCase(),
          selector: getSelector(e.target),
          x: e.clientX,
          y: e.clientY
        });
        return;
      }

      var props = {
        tag: target.tagName.toLowerCase(),
        selector: getSelector(target),
        text: getElText(target)
      };

      // Link click
      if (target.tagName === "A") {
        var href = target.getAttribute("href");
        if (href) props.href = href;
        try {
          var u = new URL(href, location.origin);
          if (u.hostname !== location.hostname) {
            props.external = true;
            enqueue("$outbound_click", props);
            return;
          }
        } catch(x) {}
      }

      // Button / interactive element click
      if (target.getAttribute("data-track")) props.track_id = target.getAttribute("data-track");
      enqueue("$click", props);
      pushBreadcrumb("click", { selector: getSelector(target), text: getElText(target).slice(0, 40) });

      // Rage click detection
      var now = Date.now();
      if (target === lastClickTarget && now - lastClickTime < RAGE_WINDOW) {
        rageCount++;
        if (rageCount >= RAGE_THRESHOLD) {
          enqueue("$rage_click", { selector: getSelector(target), text: getElText(target), clicks: rageCount + 1 });
          rageCount = 0;
        }
      } else {
        rageCount = 1;
      }
      lastClickTime = now;
      lastClickTarget = target;

    }, true); // capture phase to get everything

    // --- 3. FORM SUBMIT ---
    document.addEventListener("submit", function(e) {
      var form = e.target;
      if (!form || form.tagName !== "FORM") return;
      var props = {
        selector: getSelector(form),
        action: form.getAttribute("action") || "",
        method: (form.getAttribute("method") || "get").toUpperCase()
      };
      // Get form field names (NOT values — privacy)
      var fields = [];
      var inputs = form.querySelectorAll("input, select, textarea");
      for (var i = 0; i < inputs.length; i++) {
        var name = inputs[i].getAttribute("name");
        if (name && name !== "password" && name !== "authenticity_token" && name !== "csrf" && name.indexOf("password") === -1) {
          fields.push(name);
        }
      }
      props.fields = fields.join(", ");
      enqueue("$form_submit", props);
      pushBreadcrumb("form", { action: props.action, method: props.method });
    }, true);

    // --- 4. INPUT CHANGE (track which fields users interact with, NOT values) ---
    document.addEventListener("change", function(e) {
      var el = e.target;
      if (!el) return;
      var tag = el.tagName;
      if (tag !== "INPUT" && tag !== "SELECT" && tag !== "TEXTAREA") return;

      var inputType = el.getAttribute("type") || "text";
      // Skip sensitive fields
      if (inputType === "password" || inputType === "hidden") return;
      var name = el.getAttribute("name") || "";
      if (name.indexOf("password") !== -1 || name.indexOf("token") !== -1 || name.indexOf("secret") !== -1) return;

      enqueue("$input_change", {
        tag: tag.toLowerCase(),
        type: inputType,
        name: name,
        selector: getSelector(el),
        // Only capture value for select/checkbox/radio (not text inputs — privacy)
        value: (tag === "SELECT" || inputType === "checkbox" || inputType === "radio") ? el.value : undefined
      });
    }, true);

    // --- 5. FOCUS / BLUR on inputs (time spent on fields) ---
    var focusedEl = null;
    var focusedAt = 0;
    document.addEventListener("focusin", function(e) {
      var el = e.target;
      if (el && (el.tagName === "INPUT" || el.tagName === "TEXTAREA" || el.tagName === "SELECT")) {
        focusedEl = el;
        focusedAt = Date.now();
      }
    }, true);
    document.addEventListener("focusout", function(e) {
      if (focusedEl && focusedAt) {
        var duration = Math.round((Date.now() - focusedAt) / 1000);
        if (duration >= 1) { // only track if focused for at least 1 second
          enqueue("$field_time", {
            selector: getSelector(focusedEl),
            name: focusedEl.getAttribute("name") || "",
            duration_seconds: duration
          });
        }
        focusedEl = null;
        focusedAt = 0;
      }
    }, true);

    // --- 6. SCROLL DEPTH ---
    maxScroll = 0;
    window.addEventListener("scroll", function() {
      var scrollTop = window.pageYOffset || document.documentElement.scrollTop;
      var docHeight = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight) - window.innerHeight;
      if (docHeight <= 0) return;
      var pct = Math.round((scrollTop / docHeight) * 100);
      if (pct > maxScroll) maxScroll = pct;
    }, { passive: true });

    // --- 7. PAGE LEAVE (scroll depth + time on page) ---
    var pageLoadTime = Date.now();
    document.addEventListener("visibilitychange", function() {
      if (document.visibilityState === "hidden") {
        // Scroll depth
        if (maxScroll > 0) {
          enqueue("$scroll_depth", { depth_percent: maxScroll });
        }

        // Time on page
        var timeOnPage = Math.round((Date.now() - pageLoadTime) / 1000);
        if (timeOnPage > 0) {
          enqueue("$page_leave", { time_on_page_seconds: timeOnPage, scroll_depth: maxScroll });
        }

        // Session end
        var s = getSession();
        enqueue("$session_end", { duration_seconds: Math.round((Date.now() - s.st) / 1000), pages_viewed: s.pc });

        flush();
      }
    });

    // --- 8. ERRORS (JS errors) ---
    window.addEventListener("error", function(e) {
      var errorType = "";
      var stack = "";
      if (e.error) {
        errorType = e.error.constructor ? e.error.constructor.name : "";
        stack = (e.error.stack || "").slice(0, 4096);
      }
      var di = deviceInfo();
      enqueue("$error", {
        message: (e.message || "").slice(0, 200),
        source: (e.filename || "").slice(0, 200),
        line: e.lineno,
        col: e.colno,
        error_type: errorType,
        stack: stack,
        browser: di.browser,
        os: di.os,
        device_type: di.device_type,
        breadcrumbs: getBreadcrumbsJSON()
      });
    });

    window.addEventListener("unhandledrejection", function(e) {
      var reason = e.reason;
      var msg = "";
      var errorType = "";
      var stack = "";
      if (reason) {
        msg = (reason.message || reason.toString() || "").slice(0, 200);
        errorType = reason.constructor ? reason.constructor.name : "";
        stack = (reason.stack || "").slice(0, 4096);
      }
      var di = deviceInfo();
      enqueue("$promise_error", {
        message: msg,
        error_type: errorType,
        stack: stack,
        browser: di.browser,
        os: di.os,
        device_type: di.device_type,
        breadcrumbs: getBreadcrumbsJSON()
      });
    });

    // --- 8b. NETWORK ERRORS (fetch monkey-patch) ---
    if (window.fetch) {
      var _origFetch = window.fetch;
      window.fetch = function(input, init) {
        var url = typeof input === "string" ? input : (input && input.url ? input.url : "");
        var method = (init && init.method ? init.method : "GET").toUpperCase();
        // Skip Tally's own endpoint
        if (url.indexOf(config.endpoint) === 0 || url.indexOf("/api/v1/") !== -1) {
          return _origFetch.apply(this, arguments);
        }
        pushBreadcrumb("network", { method: method, url: url.slice(0, 200) });
        var di = deviceInfo();
        return _origFetch.apply(this, arguments).then(function(resp) {
          if (resp.status >= 400) {
            enqueue("$network_error", {
              url: url.slice(0, 200),
              status: resp.status,
              method: method,
              browser: di.browser,
              os: di.os,
              device_type: di.device_type
            });
          }
          return resp;
        });
      };
    }

    // --- 9. COPY / PASTE ---
    document.addEventListener("copy", function(e) {
      var sel = (window.getSelection() || "").toString().trim();
      enqueue("$copy", { text_length: sel.length, selector: getSelector(e.target) });
    });

    // --- 10. WINDOW RESIZE ---
    var resizeTimer = null;
    window.addEventListener("resize", function() {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(function() {
        enqueue("$resize", { viewport: window.innerWidth + "x" + window.innerHeight });
      }, 1000);
    });
  }

  function autoPageview() {
    pushBreadcrumb("navigation", { path: window.location.pathname });
    var s = bumpSession();
    var p = { page_count: s.pc };
    if (s.ref) p.referrer = s.ref;
    if (s.lp) p.landing_page = s.lp;
    Object.assign(p, utmParams());
    enqueue("$pageview", p);
    // Reset scroll tracking for new page
    maxScroll = 0;
  }

  function autoSessionStart() {
    enqueue("$session_start", Object.assign({}, deviceInfo(), utmParams(), {
      referrer: document.referrer || null,
      landing_page: window.location.pathname
    }));
  }

  // ==== PUBLIC API ====

  window.tally = function(cmd) {
    var a = [].slice.call(arguments, 1);
    switch(cmd) {

      case "init":
        config.apiKey = a[0];
        var o = a[1] || {};
        config.endpoint = o.endpoint || location.origin;
        config.autotrack = o.autotrack !== false;
        setInterval(flush, FLUSH_INTERVAL);
        if (config.autotrack) {
          if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", setupAutocapture);
          else setupAutocapture();
        }
        break;

      case "track":
        enqueue(a[0], a[1] || {});
        break;

      case "identify":
        var uid = a[0], props = a[1] || {};
        setUserId(uid);
        post(config.endpoint + "/api/v1/identify", { user_id: uid, properties: props, api_key: config.apiKey });
        post(config.endpoint + "/api/v1/alias", { anonymous_id: getAnonId(), user_id: uid, api_key: config.apiKey });
        break;

      case "reset":
        setUserId(null);
        try { localStorage.removeItem(KEY_ANON); localStorage.removeItem(KEY_USER); sessionStorage.removeItem(KEY_SESSION); } catch(e){}
        break;

      case "get_distinct_id":
        return getUserId() || getAnonId();
    }
  };
})();
