# ClawBot

Dockerized [OpenClaw](https://github.com/openclaw) gateway behind a **Caddy** reverse proxy, with local **Ollama** and cloud **DeepSeek** inference.

## Setup

### Prerequisites

- **Docker** (Engine or Desktop) on the gateway host
- GNU Make
- A static LAN IP for the host — configure it in `settings`

### 1. DNS & firewall

Create a free account at [DuckDNS](https://duckdns.org) and register a subdomain. Set its IPv4 to your LAN IP. Add your domain and token to `.env`:

```bash
# .env
DUCKDNS_DOMAIN=my-local-server.duckdns.org
DUCKDNS_TOKEN=<your-token>
```

Open ports 80/443 to your LAN subnet only. The subnet and port values below match the defaults in `settings`:

```bash
sudo ufw allow from 10.20.30.0/24 to 10.20.30.5 port 80 proto tcp
sudo ufw allow from 10.20.30.0/24 to 10.20.30.5 port 443 proto tcp
```

### 2. Configure settings

Config lives in two files with a clear boundary:

| File | Committed? | Purpose |
|------|-----------|---------|
| `settings` | Yes | Non-secret defaults: LAN IP, subnet, gateway port. Edit here for your network. |
| `.env` | No (gitignored) | Secrets: `OPENCLAW_GATEWAY_PASSWORD` (auto-generated), `DUCKDNS_TOKEN` (your API key), `DEEPSEEK_API_KEY`. |

`settings` is committed and safe to share — no secrets. To override a default, set the same key in `.env` (loaded after `settings` and takes precedence). If your LAN IP changes, edit `settings`. If you need to add an API key for a cloud provider, put it in `.env`.

```
# settings  (committed, no secrets)
OPENCLAW_LAN_IP=10.20.30.5
OPENCLAW_LAN_SUBNET=10.20.30.0/24
OPENCLAW_DOCKER_SUBNET=172.30.0.0/16
OPENCLAW_GATEWAY_PORT=18789
```

### 3. Deploy

```bash
make init
```

This runs `verify_env → gen_password → down → build → configure-seed → llm-model-pull → run → wait-healthy → doctor-lint`. When it returns, the system is running, healthy, and validated (0 findings).

### 4. Pair your browser

Visit `https://<your DUCKDNS_DOMAIN>`. Find and approve the pairing request:

```bash
make devices-pending      # prints copy-pasteable approve command
```

Click **Reconnect** in the browser. Done once per device.

## LLM Backend

Two inference modes controlled by `DEBUG` in `.env`:

| `DEBUG`    | Provider    | Runtime                          | Needs API key?        |
|-----------|------------|----------------------------------|-----------------------|
| `true`    | Ollama      | `qwen2.5:7b` in Docker container | No                    |
| `false`   | DeepSeek    | Cloud API                        | `DEEPSEEK_API_KEY`    |

Set in `.env`:

```bash
# .env
DEBUG=true   # local inference (default)
```

Or:

```bash
DEBUG=false  # switch to DeepSeek cloud
```

Then apply:

```bash
make restart
```

### Local inference (Ollama)

When `DEBUG=true`, `make init` starts the Ollama container and pulls `qwen2.5:7b`. Ollama listens on Docker DNS `ollama:11434`, no auth needed. Models are cached in the `ollama_data` Docker volume.

> **TODO**: Ollama's OpenAI-compatible endpoint rejects tool call arguments sent as objects (expects JSON strings). Tool-using turns fail with `json: cannot unmarshal object into Go struct field .messages.tool_calls.function.arguments`. Simple chat works fine. Track Ollama issue or use DeepSeek for tool-using sessions until resolved.

Start Ollama manually:

```bash
make llm     # start ollama + pull qwen2.5:7b
```

Pull a different model:

```bash
docker compose exec ollama ollama pull llama3.2
```

Then add it to `services/openclaw/openclaw.patch.local.json5` (under `models.providers`) and run `make reconfigure`.

### Cloud inference (DeepSeek)

When `DEBUG=false`, set your API key in `.env`:

```bash
DEEPSEEK_API_KEY=sk-...
make restart
```

### Adding providers

Two patch files under `services/openclaw/`, selected by `DEBUG`:

| File | Used when |
|------|-----------|
| `openclaw.patch.local.json5` | `DEBUG=true` |
| `openclaw.patch.cloud.json5` | `DEBUG=false` |

Each file contains the full gateway config for that mode — no merging or conditionals needed. To add a provider (e.g. OpenAI), add it to the appropriate patch file's `models.providers` block and run `make reconfigure`. See [OpenClaw provider docs](https://docs.openclaw.ai/gateway/configuration#choose-and-configure-models) for provider config details.

## Workspace

The agent workspace lives at `workspace/` (mounted to `~/.openclaw/workspace` inside the container). OpenClaw initializes it as a git repo on first run. Keep it in its own private remote — OpenClaw recommends this for backup and portability.

### Back up

```bash
cd workspace
git remote add origin <your-private-repo-url>
git push -u origin main
```

Periodically commit and push new memory, identity, and habit files:

```bash
cd workspace && git add . && git commit -m "memory update" && git push
```

### Restore on a new machine

```bash
rm -rf workspace
git clone <your-private-repo-url> workspace
```

## Daily Commands

```bash
make status        # show container state + gateway health
make run           # start services
make down          # stop services (data preserved)
make restart       # stop → start → wait healthy
make logs          # tail gateway + Caddy logs
make reconfigure   # apply openclaw.patch.*.json5 changes without rebuilding
make rebuild       # rebuild images from scratch + redeploy
make llm           # start Ollama + pull qwen2.5:7b
make cli ARGS="..." # run any openclaw command (doctor, devices, status, etc.)
make doctor-lint   # read-only health check
make doctor-fix    # run health repairs
make qr            # pairing QR for mobile devices
make reset         # full teardown and re-init
```

## Adding Devices

### Browser

Visit `https://<your DUCKDNS_DOMAIN>` and approve:

```bash
make devices-pending      # prints copy-pasteable approve command
```

### Mobile (Android / iOS)

1. Install the OpenClaw app
2. Generate a QR code: `make qr`
3. In the app: **Connect → Setup Code → scan the QR**
4. The device auto-pairs. The app will show "checking node capability approval." Approve on the host:
```bash
make nodes-status                         # look for "approval pending"
make nodes-pending                        # prints copy-pasteable command
make nodes-approve REQ=<request-id>
```

Node capabilities must be re-approved whenever the app adds new commands (e.g. location, camera access). `make nodes-pending` surfaces the request ID.

## Configuration

| File | How to apply changes |
|------|---------------------|
| `services/openclaw/openclaw.patch.*.json5` | `make reconfigure` |
| `services/caddy/Caddyfile` | `make rebuild` |
| `services/openclaw/Dockerfile` | `make rebuild` |
| `settings` | `make rebuild` |
| `.env` | `make rebuild` |

Gateway settings (models, auth, origins, rate limits) only need `reconfigure`. Infrastructure changes (Caddyfile, Dockerfiles, settings, env) require `rebuild`.

The gateway uses `password` auth mode — the Control UI prompts for the password on first visit. The password is stored as a SecretRef (`{ source: "env", provider: "default", id: "OPENCLAW_GATEWAY_PASSWORD" }`) so the value never touches the config file. Caddy terminates TLS, restricts access to your LAN subnet, and shares the gateway's network namespace so both communicate over loopback.


## Makefile Reference

### Workflows

| Target | What it does | When to use |
|--------|-------------|-------------|
| `make init` | Full first-time setup. Idempotent, safe to re-run. | Brand new install |
| `make rebuild` | Rebuild images from scratch + redeploy. | Changed Dockerfiles, Caddyfile, or need fresh base images |
| `make reconfigure` | Apply `openclaw.patch.*.json5` changes. No rebuild. | Only changed gateway config |
| `make restart` | Stop + start services, wait healthy. | Quick restart, data preserved |
| `make reset` | Destroy everything (volumes) and re-init. | Start completely fresh |
| `make doctor-lint` | Read-only health check | Diagnose issues |
| `make doctor-fix` | Apply health repairs | Fix issues automatically |
| `make doctor ARGS=...` | Run doctor with custom flags | Any other doctor operation |
| `make status` | Show container state + gateway health. | Check if system is running |

### Docker lifecycle

| Target | Description |
|--------|-------------|
| `make run` | Start gateway + Caddy + Ollama (if `DEBUG=true`) |
| `make down` | Stop and remove containers (volumes/data preserved) |
| `make logs` | Tail gateway + Caddy logs |

### OpenClaw operations

| Target | Description |
|--------|-------------|
| `make llm` | Start Ollama + pull `qwen2.5:7b` |
| `make cli ARGS="..."` | Run any openclaw command (e.g. `cli ARGS="status"`, `cli ARGS="doctor --deep"`) |
| `make doctor ARGS=...` | Run doctor with custom flags |
| `make doctor-lint` | Run `doctor --lint` (read-only) |
| `make doctor-fix` | Run `doctor --fix` (apply repairs) |
| `make qr` | Generate pairing QR for mobile devices |
| `make devices-list` | List paired and pending devices |
| `make devices-pending` | Print pending device IDs as copy-pasteable approve commands |
| `make devices-approve REQ=<id>` | Approve a pending device |
| `make nodes-status` | List connected nodes and approval state |
| `make nodes-pending` | Print pending node approval IDs as copy-pasteable commands |
| `make nodes-approve REQ=<id>` | Approve node capabilities |
| `make security-audit` | Run OpenClaw security audit |

## How it works

```
Ollama (Docker) ←─────────────────────────────┐
                                                │ Docker network
Caddy (Docker, TLS) ── 127.0.0.1 ──→ openclaw-gateway (Docker)
       ↑ shared network namespace               │
       └─────────────────────────────────────────┘
                          ↕
                    DeepSeek API (cloud)
                          ↑
                  LAN clients (10.20.30.0/24)
```

Caddy and the gateway share a network namespace (`network_mode: service:openclaw-gateway`). This lets the gateway bind to `127.0.0.1` (loopback) while Caddy still reaches it. The gateway port is published to host `127.0.0.1` only — no external access. Caddy terminates TLS at your `DUCKDNS_DOMAIN` via Let's Encrypt and restricts access to your LAN subnet (`OPENCLAW_LAN_SUBNET`). Ollama runs on the Docker bridge network, reachable at `ollama:11434`.
