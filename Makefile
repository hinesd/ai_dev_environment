-include .env

# `local` (default) — loopback only. Gateway on 127.0.0.1.
# `lan`            — local + Caddy reverse proxy with DuckDNS TLS + IP filter.
# Set it in .env.
MODE ?= local

DOCKER_COMPOSE := docker compose -f compose.yaml

ifeq ($(MODE),lan)
  DOCKER_COMPOSE := $(DOCKER_COMPOSE) -f compose.lan.yaml
endif

ifneq (,$(LOCAL_MODEL))
  DOCKER_COMPOSE := $(DOCKER_COMPOSE) --profile local-model
endif

include $(wildcard .make/*.mk)

OPENCLAW := $(DOCKER_COMPOSE) exec -T openclaw-gateway node dist/index.js

# ═══════════════════════════════════════════════════════════════════
#  Commands
# ═══════════════════════════════════════════════════════════════════

# init — First-time setup. Idempotent, safe to re-run.
.PHONY: init
init: verify_env model-pull down build run doctor-lint
	@echo ""
	@echo "Init complete — system is running."

# cli — Run any openclaw command (make cli ARGS="status").
.PHONY: cli
cli:
	$(OPENCLAW) $(ARGS)

# doctor — Run openclaw doctor (make doctor ARGS="--fix").
.PHONY: doctor
doctor:
	$(OPENCLAW) doctor $(ARGS)

# status — Show container state and gateway health.
.PHONY: status
status:
	@$(DOCKER_COMPOSE) ps
	@echo ""
	@$(OPENCLAW) doctor --lint 2>/dev/null || echo "Gateway: check failed"

# rebuild — Rebuild images from scratch and redeploy.
.PHONY: rebuild
rebuild: down build-nocache run doctor-lint

# restart — Stop and restart services. Data is preserved.
.PHONY: restart
restart: down run
	@echo ""
	@echo "Restart complete — system is running."

# reset — Destroy everything (volumes, state) and re-initialize.
#   Use to start completely fresh.
.PHONY: reset
reset: clean init

# run — Start all services and wait for them to be healthy.
.PHONY: run
run: verify_ip
	$(DOCKER_COMPOSE) up -d --wait --wait-timeout 120