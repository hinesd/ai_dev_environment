DOCKER_COMPOSE := docker compose
OPENCLAW      := $(DOCKER_COMPOSE) exec -T openclaw-gateway node dist/index.js
OPENCLAW_RUN  := $(DOCKER_COMPOSE) run --rm -T --no-deps --entrypoint node openclaw-gateway dist/index.js

include .make/env.mk
include .make/docker.mk
include .make/openclaw.mk
include .make/workflows.mk

# ═══════════════════════════════════════════════════════════════════
#  Commands
# ═══════════════════════════════════════════════════════════════════

# init — First-time setup. Idempotent, safe to re-run.
.PHONY: init
init: verify_env gen_password down build configure-seed llm-model-pull run wait-healthy doctor-lint
	@echo ""
	@echo "Init complete — system is running."
	@echo "  Dashboard: https://$(DUCKDNS_DOMAIN)"

# rebuild — Rebuild images from scratch and redeploy.
.PHONY: rebuild
rebuild: down build-nocache configure-seed llm-model-pull run wait-healthy doctor-lint
	@echo ""
	@echo "Rebuild complete — system is running."

# run — Start all services.
.PHONY: run
run:
	$(DOCKER_COMPOSE) $(COMPOSE_PROFILE) up -d

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
