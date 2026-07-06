-include .env
MODEL_DEFAULT ?= ollama/qwen2.5:7b

ifneq (,$(findstring ollama,$(MODEL_DEFAULT)))
  COMPOSE_PROFILE := --profile ollama
else
  COMPOSE_PROFILE :=
endif
DOCKER_COMPOSE := docker compose $(COMPOSE_PROFILE)

export MODEL_DEFAULT

OPENCLAW := $(DOCKER_COMPOSE) exec -T openclaw-gateway node dist/index.js

include .make/env.mk
include .make/docker.mk
include .make/openclaw.mk
include .make/ollama.mk
include .make/workflows.mk

# ═══════════════════════════════════════════════════════════════════
#  Commands
# ═══════════════════════════════════════════════════════════════════

# init — First-time setup. Idempotent, safe to re-run.
.PHONY: init
init: verify_env gen_password down build ollama-model-pull config run wait-healthy doctor-lint
	@echo ""
	@echo "Init complete — system is running."
	@echo "  Dashboard: https://$(DUCKDNS_DOMAIN)"

# config — Apply all patches (works with or without running gateway).
.PHONY: config
config:
	@echo "Applying patches..."
	@for f in src/openclaw/patches/*.json5; do \
		cat "$$f" | $(DOCKER_COMPOSE) run --rm -T --no-deps --entrypoint node openclaw-gateway dist/index.js config patch --stdin; \
	done

# rebuild — Rebuild images from scratch and redeploy.
.PHONY: rebuild
rebuild: down build-nocache ollama-model-pull config run wait-healthy doctor-lint

# run — Start all services.
.PHONY: run
run:
	$(DOCKER_COMPOSE) up -d

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
