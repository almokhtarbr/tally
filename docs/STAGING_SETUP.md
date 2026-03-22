# Staging Setup — Local Dev with Cloudflare Tunnel

Run Tally locally on your laptop and expose it via your staging domain. No server needed.

## How It Works

```
                        Internet
                           │
  User/SDK hits    ┌───────▼────────┐
  staging.yourdomain.com   │  Cloudflare    │
                   │  (DNS + TLS)   │
                   └───────┬────────┘
                           │ encrypted tunnel
                           │ (outbound connection
                           │  from YOUR machine)
                   ┌───────▼────────┐
                   │  cloudflared   │  ← runs on your laptop
                   │  (tunnel agent)│
                   └───────┬────────┘
                           │ localhost:3000
                   ┌───────▼────────┐
                   │  Rails (Tally) │  ← your local dev server
                   │  + PostgreSQL  │  ← local database
                   └────────────────┘
```

1. You start Rails locally (`bin/dev`) with Postgres on your machine
2. `cloudflared` opens a persistent outbound connection from your laptop to Cloudflare's edge — no port forwarding or firewall changes needed
3. Your domain DNS points to the tunnel (`staging.yourdomain.com` → Cloudflare Tunnel)
4. Requests to `staging.yourdomain.com` are received by Cloudflare, TLS terminated, and forwarded through the tunnel to your laptop
5. `cloudflared` proxies to `localhost:3000` — Rails handles it like a normal request
6. Response goes back the same path

## What This Gives You

- **JS SDK works**: `<script src="https://staging.yourdomain.com/sdk/tally.js">` on any site, events flow to local Rails
- **HTTPS**: Cloudflare handles the cert automatically
- **Webhooks**: any external service can POST to your domain
- **Full local debugging**: `binding.pry`, `rails console`, logs in your terminal
- **No server costs**: runs on your machine
- **Downside**: only works when your laptop is on and `cloudflared` is running

## Requirements

| What | Where | Cost |
|------|-------|------|
| Cloudflare account | cloudflare.com | Free |
| `cloudflared` CLI | your laptop | Free |
| PostgreSQL | your laptop | Free |
| Rails app (Tally) | your laptop | Free |
| Domain name | any registrar | Already owned |
| Server | none needed | $0 |

## Setup

### 1. Add Your Domain to Cloudflare

- Sign up at [cloudflare.com](https://cloudflare.com) (free plan)
- Add your domain — Cloudflare becomes your DNS provider
- Update your domain registrar's nameservers to point to Cloudflare

### 2. Install and Configure Cloudflare Tunnel

```bash
# Install cloudflared
brew install cloudflared

# Login to your Cloudflare account
cloudflared tunnel login

# Create a tunnel named "tally"
cloudflared tunnel create tally

# Point your subdomain at the tunnel
cloudflared tunnel route dns tally staging.yourdomain.com
```

Create a config file at `~/.cloudflared/config.yml`:

```yaml
tunnel: tally
credentials-file: ~/.cloudflared/TUNNEL_ID.json

ingress:
  - hostname: staging.yourdomain.com
    service: http://localhost:3000
  - service: http_status:404
```

Replace `TUNNEL_ID` with the actual tunnel ID from the `cloudflared tunnel create` output.

### 3. Set Up Local Rails App

```bash
# Install dependencies
bundle install

# Set up database
bin/rails db:create db:migrate

# Start the app
bin/dev
```

### 4. Start the Tunnel

In a separate terminal:

```bash
cloudflared tunnel run tally
```

Your app is now live at `https://staging.yourdomain.com`.

## Moving to Production Later

When ready for real production, get a server and deploy with Kamal. Best options for free trials:

| Provider | Free Credit | Notes |
|----------|-------------|-------|
| **Hetzner Cloud** | €20 credit | Kamal was built for this. Cheapest long-term (€4.5/mo) |
| **DigitalOcean** | $200 / 60 days | Very Kamal-friendly, lots of guides |
| **Vultr** | $100 / 30 days | Simple, good performance |
| **Oracle Cloud** | Always-free ARM VM (4 CPU/24GB) | Generous but signup can be finicky |

Minimum server spec for staging: **2 vCPU / 2-4GB RAM, Ubuntu 24.04, ports 80/443/22 open**.
