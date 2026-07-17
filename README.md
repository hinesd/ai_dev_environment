# AI Dev Environment

Dockerized [OpenClaw](https://github.com/openclaw) gateway, with local inference via **Docker Model Runner** (llama.cpp) and cloud inference via **DeepSeek**. Runs in two modes: **local** (default, loopback only) or **lan** (Caddy reverse proxy with DuckDNS TLS and IP filter for trusted devices on your network).

## Quick start

```bash
# 1. Copy and edit .env
cp .env.example .env
# → Set OPENCLAW_GATEWAY_PASSWORD (replace REPLACE_ME)
# → Optionally set DEEPSEEK_API_KEY for cloud inference

# 2. Deploy
make init
```

That's it for local mode — the gateway is at `http://127.0.0.1:18789`, loopback only.

## Modes

| | `MODE=local` (default) | `MODE=lan` |
|---|---|---|
| Compose files | `compose.yaml` | `compose.yaml` + `compose.lan.yaml` |
| Services | gateway (+ local-model) | gateway (+ local-model) + Caddy |
| Reachable from | this machine only (`127.0.0.1`) | devices on `TRUSTED_SUBNET`, via TLS |
| Required config | `OPENCLAW_GATEWAY_PASSWORD` | + `STATIC_IP`, `TRUSTED_SUBNET`, `DUCKDNS_DOMAIN`, `DUCKDNS_TOKEN` |

Set `MODE` in `.env`. All `make` commands work identically in both modes; switching is `MODE=lan` + `make restart`. The networking and device-pairing sections below apply to lan mode.

## Architecture

Diagram shows `MODE=lan`; in `MODE=local` the Caddy box and 80/443 exposure don't exist — clients on this machine connect straight to `127.0.0.1:18789`.

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
| `MODE` | `local` (default, loopback only) or `lan` (Caddy TLS on `STATIC_IP`) |
| `LOCAL_MODEL` | Set to `llama-cpp` to enable local inference via Docker Model Runner |
| `LOCAL_MODEL_ID` | Model to pull and run (Docker Hub or HuggingFace reference) |
| `LOCAL_MODEL_PORT` | Port Docker Model Runner serves on (default 12434) |
| `STATIC_IP` | Host IP for Caddy to bind 80/443 (lan mode only) |
| `TRUSTED_SUBNET` | Subnet allowed through Caddy's IP filter (lan mode only) |
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
LOCAL_MODEL_ID=huggingface.co/bartowski/google_gemma-3-1b-it-gguf:latest
```

When `LOCAL_MODEL` is set, the Makefile appends `--profile local-model` to all compose commands. Compose pulls the model on first `up` and starts the server automatically; subsequent starts reuse the cached model. `make init` includes a `model-pull` step to pre-cache it.

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
| `src/caddy/Caddyfile` | On restart (lan mode) |
| `.env` | On restart |
| `compose.yaml` | On restart |
| `compose.lan.yaml` | On restart (lan mode) |

Patches are applied by the gateway's startup command — no separate `make config` step needed. They're idempotent; the gateway re-applies them on every start.

### Available patches

```
src/openclaw/patches/
├── agents.json5            # agent defaults
├── models.deepseek.json5   # DeepSeek cloud provider
├── models.local.json5      # local model provider (Docker Model Runner)
└── network/
    ├── local.json5         # bind: 0.0.0.0 (local loopback access)
    └── lan.json5           # bind: loopback (Caddy shared namespace)
```

To add a new patch, drop a `.json5` file in the patches directory and restart.

## Networking (lan mode)

In `MODE=local` there is nothing to configure: the gateway listens on `127.0.0.1:18789` and nothing else is exposed. Everything below applies to `MODE=lan`.

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

**Acceptable but weaker:** your general local subnet (e.g. `192.168.1.0/24`). Layer 3 still blocks untrusted IPs, but any device on your network (including guest devices or IoT hardware, if they share the subnet) can at minimum reach the Caddy socket.

Most managed switches and all-in-one routers support VLANs for this purpose. Configure your router to block inter-VLAN routing between the trusted network and any others, then point `STATIC_IP` and `TRUSTED_SUBNET` at that VLAN.

### DuckDNS and local traffic

DuckDNS resolves `DUCKDNS_DOMAIN` to `STATIC_IP` — a private address. Connections from trusted devices therefore stay entirely within your local network; no traffic reaches the public internet. This also means TLS certificates are obtained via DNS-01 challenge (not HTTP-01), so port 80/443 never need to be exposed to the internet.

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

## Troubleshooting

**`ERROR: STATIC_IP=... is not assigned to any interface`** (lan mode) — `make run` checks that the IP exists on the host before starting. Your machine's LAN IP has changed (DHCP), you're on a different network, or `.env` has a typo. Update `STATIC_IP` (and give the host a static lease in your router so it stops moving), or set `MODE=local`.

**Ports 80/443 already in use** — Another service (nginx, Apache, AirPlay Receiver on macOS) is bound to the port. Find it with `sudo lsof -iTCP:443 -sTCP:LISTEN` and stop it, or move this host to a dedicated IP.

**Gateway never becomes healthy** — `docker compose up --wait` (run by `make run`) fails after 120s. Run `make logs` and look at `openclaw-gateway` output; the usual causes are a bad patch file in `src/openclaw/patches/` or corrupted state under `state/`. `make doctor ARGS="--fix"` repairs common config issues.

**TLS certificate errors / `curl` says self-signed** — Caddy obtains certificates via DuckDNS DNS-01. Check `make logs` for `caddy` errors: an invalid `DUCKDNS_TOKEN`, a domain that doesn't match `DUCKDNS_DOMAIN`, or (rarely) a Let's Encrypt rate limit. The DuckDNS record must also point at `STATIC_IP` for clients to reach the right host.

**Model pull fails** — `docker model pull` needs Docker Model Runner enabled (Docker Desktop → Settings → AI) and network access to Docker Hub / Hugging Face. Verify the reference with `docker model search <query>`; gated HF models require `docker login` against the HF registry.

**Model runs but responses are slow or OOM** — The model may not fit in memory/VRAM. Try a smaller quantization or lower `context_size` in `docker-compose.yml`.

## Adding a new `.mk` module

Drop a `.mk` file in `.make/` — it's automatically included via `$(wildcard .make/*.mk)`. No changes to the Makefile needed.

## How `make init` works

```
verify_env → model-pull → down → build → run → doctor-lint
```

1. **verify_env** — ensures `.env` exists and required values are filled in (password set; DuckDNS vars in lan mode)
2. **model-pull** — pulls the local model if `LOCAL_MODEL` is set
3. **down** — stops any running containers
4. **build** — builds Docker images (OpenClaw gateway; + Caddy in lan mode)
5. **run** — verifies `STATIC_IP` (lan mode), then `docker compose up -d --wait` — compose starts everything and blocks until health checks pass (120s timeout)
6. **doctor-lint** — runs read-only health checks (warnings are non-fatal)
