# ClawBot

Dockerized [OpenClaw](https://github.com/openclaw) gateway for local development, using **LM Studio** as the LLM backend.

## Architecture

```
┌──────────────┐     ┌──────────────────┐     ┌────────────┐
│  LM Studio   │◄────│ openclaw-gateway │◄────│  Browser   │
│  :1234       │     │ :18789           │     │ localhost  │
└──────────────┘     └──────────────────┘     └────────────┘
     host                    Docker                host
```

- **openclaw-gateway** — the OpenClaw service (pre-built image `ghcr.io/openclaw/openclaw:latest`)
- **openclaw-cli** — CLI tooling (profiled, only runs on demand)
- **LM Studio** — runs natively on the host, reached via `host.docker.internal:1234`

## Prerequisites

- **Docker** (Desktop or Engine)
- **LM Studio** running on the host with `--bind 0.0.0.0`
- GNU Make

## Quick Start

```bash
make setup
```

This rebuilds the image, starts the gateway, applies the seed config, and restarts. After setup:

```bash
make dashboard    # open the Control UI
make logs         # tail gateway logs
make token        # print the gateway token
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make build` | Build the gateway image |
| `make rebuild` | Rebuild from scratch (no cache) |
| `make up` | Start the gateway in detached mode |
| `make run` | Start the gateway in foreground |
| `make down` | Stop and remove containers |
| `make setup` | Full automated setup: `rebuild → up → wait-healthy → configure` |
| `make configure` | Apply `openclaw/seed.json` to the running gateway |
| `make onboarding` | Run the interactive onboarding wizard |
| `make wait-healthy` | Poll `:18789/healthz` until the gateway is ready |
| `make dashboard` | Launch the Control UI (in the CLI container) |
| `make security-audit` | Run the OpenClaw security audit |
| `make token` | Print the gateway auth token |
| `make cli CMD="..."` | Run an arbitrary OpenClaw CLI command |
| `make channels CMD="..."` | Manage messaging channels (e.g. `login`) |
| `make logs` | Tail gateway logs |
| `make clean` | Tear down everything, including volumes |

## Configuration

All gateway settings live in **`openclaw/seed.json`** — the single source of truth. It configures:

- Gateway mode (`local`), bind address (`lan`)
- CORS origins, auth rate limiting
- LM Studio provider with `qwen/qwen3.5-9b` as the default model
- Tool denials for web search (LM Studio models lack native web browsing)
- Agent workspace path

`make configure` applies `seed.json` to a running gateway via `config set --batch-json`.

## Persistence

Bind mounts under `./docker_persist/` survive container replacement:

| Host Path | Container Path | Purpose |
|-----------|---------------|---------|
| `docker_persist/config/` | `/home/node/.openclaw/` | Gateway config (`openclaw.json`) |
| `docker_persist/workspace/` | `/home/node/.openclaw/workspace/` | Agent workspace files |
| `docker_persist/auth-secrets/` | `/home/node/.config/openclaw/` | Encrypted auth secrets |

These directories are gitignored. Config files are directly editable on the host.

## Gateway Token

A token is auto-generated on first `make up` (stored in `.env`). The `.env.example` file is the template — never commit `.env`.

## Notes

- **LM Studio networking**: The compose file maps `host.docker.internal` to the host gateway. LM Studio must listen on `0.0.0.0` (not just `127.0.0.1`).
- **No sandbox**: Container sandboxing is disabled. The sandbox Dockerfile (`openclaw/sandbox.Dockerfile`) is retained for future use.
- **Docker Desktop caution**: Docker Desktop's Dev Environments GUI modifies `docker-compose.yml` and `Dockerfile` on disk. If you see injected `USER root` or `docker-ce-cli` lines, revert with `git checkout -- openclaw/Dockerfile docker-compose.yml && make build`.
