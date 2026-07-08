# AI Dev Environment

Dockerized [OpenClaw](https://github.com/openclaw) gateway behind a **Caddy** reverse proxy, with local inference via **Docker Model Runner** (llama.cpp) and cloud inference via **DeepSeek**.

## Quick start

```bash
# 1. Copy and edit .env
cp .env.example .env
# → Fill in DUCKDNS_DOMAIN, DUCKDNS_TOKEN, DEEPSEEK_API_KEY
# → Set OPENCLAW_GATEWAY_PASSWORD (replace REPLACE_ME)

# 2. Deploy
make init
```

## Architecture

```
                    LAN Clients (10.20.30.0/24)
                           │
                           ▼
              ┌─────────────────────────┐
              │   Host (10.20.30.4)      │
              │                         │
              │  ┌───────────────────┐  │
              │  │  Caddy (Docker)    │  │  TLS termination (DuckDNS Let's Encrypt)
              │  │  ports 80, 443     │  │  IP-based access control
              │  │  network_mode:     │  │
              │  │   "service:gw"     │──┤  Shared network namespace
              │  └───────┬───────────┘  │
              │          │ 127.0.0.1    │
              │  ┌───────▼───────────┐  │
              │  │  openclaw-gateway │  │  Binds loopback only
              │  │  port 18789       │  │  Password auth
              │  │  openclaw-net     │──┤
              │  └───────┬───────────┘  │
              │          │              │
              │  ┌───────▼───────────┐  │
              │  │  local-model      │  │  Profile-gated (--profile local-model)
              │  │  (alpine, profile)│  │  Binds model via compose models: element
              │  │  openclaw-net     │  │
              │  └───────────────────┘  │
              │                         │
              │  Docker Model Runner    │  Runs on host (Metal GPU on macOS)
              │  llama.cpp engine       │  Serves at host.docker.internal:12434
              │                         │
                       ↕ DeepSeek API (cloud)
```

## Configuration

All settings in `.env`:

| Variable | Purpose |
|----------|---------|
| `LOCAL_MODEL` | Set to `llama-cpp` to enable local inference via Docker Model Runner |
| `LOCAL_MODEL_ID` | Model to pull and run (Docker Hub or HuggingFace reference) |
| `LOCAL_MODEL_PORT` | Port Docker Model Runner serves on (default 12434) |
| `STATIC_IP` | Host LAN IP for Caddy to bind 80/443 |
| `TRUSTED_SUBNET` | LAN subnet allowed through Caddy's IP filter |
| `DOCKER_SUBNET` | Docker bridge subnet (for Caddy's IP filter on macOS) |
| `GATEWAY_PORT` | OpenClaw gateway loopback port |
| `OPENCLAW_GATEWAY_PASSWORD` | Gateway auth password (replace `REPLACE_ME`) |
| `DUCKDNS_DOMAIN` / `DUCKDNS_TOKEN` | DuckDNS domain for Let's Encrypt TLS |
| `DEEPSEEK_API_KEY` | DeepSeek API key for cloud inference |

## Local model

Local inference runs through **Docker Model Runner** with the **llama.cpp** engine — works on macOS (Metal), Linux, and Windows. The model lifecycle is fully managed by Docker Compose via the `models:` top-level element.

### Enable

```bash
# .env
LOCAL_MODEL=llama-cpp
LOCAL_MODEL_ID=hf.co/bartowski/google_gemma-3-1b-it-GGUF
```

When `LOCAL_MODEL` is set, the Makefile appends `--profile local-model` to all compose commands. Compose pulls the model on first `up` and starts the server automatically. `make init` includes a `model-pull` step to pre-cache it.

### Disable

Comment out or remove `LOCAL_MODEL` from `.env`. The model won't start. The provider config in openclaw is harmless when unused.

### Change model

Update `LOCAL_MODEL_ID` in `.env` and restart. To find available models:

```bash
docker model search <query>
docker model pull <model-id>
```

### Requirements

- **Docker Desktop 4.62+** (macOS) or **Docker Engine** (Linux/Windows)
- Docker Model Runner enabled (built into Docker Desktop)
- `LOCAL_MODEL_PORT=12434` (Docker Model Runner default)

## LLM Providers

The dev environment ships with two providers, both always configured:

| Provider | Type | Model | Tool calling |
|----------|------|-------|-------------|
| `local-model` | Docker Model Runner (llama.cpp) | Configurable via `LOCAL_MODEL_ID` | Yes |
| `deepseek` | Cloud API | `deepseek-chat` | Yes |

The agent uses `deepseek/deepseek-chat` by default (no model.primary set in agents.json5 — openclaw picks its built-in default).

### Cloud inference (DeepSeek)

Set your API key in `.env`:

```bash
DEEPSEEK_API_KEY=sk-...
```

## Daily commands

```bash
make init           # first-time setup (pulls model, builds, starts, health checks)
make run            # start all services
make restart        # stop + start
make down           # stop services (data preserved)
make rebuild        # rebuild images from scratch + redeploy
make reset          # destroy everything + re-init
make status         # container state + gateway health
make logs           # tail all logs
make cli ARGS="..." # run any openclaw command
```

## Devices

```bash
# Browser: visit https://<your DUCKDNS_DOMAIN>
make devices-pending                    # find pairing request
make devices-approve REQ=<request-id>  # approve it

# Mobile:
make qr                                 # generate pairing QR
make nodes-pending                      # find node request
make nodes-approve REQ=<request-id>    # approve it
```

## Configuration files

| File | When applied |
|------|-------------|
| `src/openclaw/patches/*.json5` | On gateway startup (auto-applied idempotently) |
| `src/caddy/Caddyfile` | On restart |
| `.env` | On restart |
| `docker-compose.yml` | On restart |

Patches are applied by the gateway's startup command — no separate `make config` step needed. They're idempotent; the gateway re-applies them on every start.

### Available patches

```
src/openclaw/patches/
├── agents.json5         # agent defaults
├── gateway.json5        # gateway auth, trusted proxies, control UI
├── models.deepseek.json5 # DeepSeek cloud provider
└── models.local.json5   # local model provider (Docker Model Runner)
```

To add a new patch, drop a `.json5` file in the patches directory and restart.

## Networking

Everything binds to `127.0.0.1` (loopback). The only external-facing ports are Caddy's 80/443 on the host's static IP.

- **Gateway**: `bind: "loopback"`, port 18789 on 127.0.0.1 only
- **Caddy**: TLS termination on 80/443, proxies to `127.0.0.1:18789`
- **Trusted proxies**: `127.0.0.1` + `DOCKER_SUBNET` — only Caddy and Docker bridge traffic are trusted
- **Auto-approve**: devices on `DOCKER_SUBNET` auto-approved for pairing
- **Caddy IP filter**: only `TRUSTED_SUBNET` + `DOCKER_SUBNET` allowed, everything else gets 403

Caddy and the gateway share a network namespace (`network_mode: service:openclaw-gateway`), so Caddy reaches the gateway at localhost with zero network hop.

### Security model

Access control is enforced in three independent layers:

| Layer | Mechanism | What it enforces |
|---|---|---|
| 1 — Network | Your router/switch/firewall | Only devices on `TRUSTED_SUBNET` can route to `STATIC_IP` at all |
| 2 — Kernel | Docker port binding to `${STATIC_IP}` | The listening socket only exists on that one interface; other interfaces on the host cannot reach it |
| 3 — Application | Caddy `remote_ip` matcher | Source IP checked against `TRUSTED_SUBNET` + `DOCKER_SUBNET` on every request; anything else gets a 403 and the connection is dropped |

All three layers must be compromised simultaneously for an untrusted client to reach the gateway. The Caddy layer works identically on every OS.

### Choosing a `TRUSTED_SUBNET`

**Recommended:** use a dedicated subnet that contains only devices you own and trust — for example a separate VLAN, a management network, or a VPN tunnel address pool. This means Layer 1 is enforced in hardware by your router before traffic ever reaches the host.

**Acceptable but weaker:** your general LAN subnet (e.g. `192.168.1.0/24`). Layer 3 still blocks untrusted IPs, but any device on your LAN (including guest devices or IoT hardware, if they share the subnet) can at minimum reach the Caddy socket.

Most managed switches and all-in-one routers support VLANs for this purpose. Configure your router to block inter-VLAN routing between the trusted network and any others, then point `STATIC_IP` and `TRUSTED_SUBNET` at that VLAN.

### DuckDNS and local traffic

DuckDNS resolves `DUCKDNS_DOMAIN` to `STATIC_IP` — a private LAN address. Connections from trusted devices therefore stay entirely within your local network; no traffic reaches the public internet. This also means TLS certificates are obtained via DNS-01 challenge (not HTTP-01), so port 80/443 never need to be exposed to the internet.

### Additional hardening on Linux

On Linux, Docker manages `iptables` automatically. You can add rules to the `DOCKER-USER` chain to enforce `TRUSTED_SUBNET` at the kernel level as a complement to Caddy's application-layer check. These rules survive Docker restarts:

```sh
# Replace with your actual TRUSTED_SUBNET and DOCKER_SUBNET values
iptables -I DOCKER-USER -p tcp --dport 443 ! -s "${TRUSTED_SUBNET}" -j DROP
iptables -I DOCKER-USER -p tcp --dport 80  ! -s "${TRUSTED_SUBNET}" -j DROP
```

Persist these rules using your distro's preferred method (`iptables-persistent`, `nftables`, `firewalld`, etc.).

### Docker Model Runner networking

The model server runs on the host (required for Metal GPU on macOS). The gateway reaches it at `host.docker.internal:12434`. The compose `models:` element manages the server lifecycle alongside other services.

## Adding a new `.mk` module

Drop a `.mk` file in `.make/` — it's automatically included via `$(wildcard .make/*.mk)`. No changes to the Makefile needed.

## How `make init` works

```
verify_env → model-pull → down → build → run → wait-healthy → doctor-lint
```

1. **verify_env** — ensures `.env` exists (copies from `.env.example` if missing)
2. **model-pull** — pulls the local model if `LOCAL_MODEL` is set
3. **down** — stops any running containers
4. **build** — builds Docker images (Caddy + OpenClaw gateway)
5. **run** — starts all services (compose handles model lifecycle if profile active)
6. **wait-healthy** — waits for the gateway health check to pass
7. **doctor-lint** — runs read-only health checks (warnings are non-fatal)
