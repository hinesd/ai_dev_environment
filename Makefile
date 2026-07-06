-include .env

DOCKER_COMPOSE := docker compose -f docker-compose.yml

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
init: verify_env model-pull down build run wait-healthy doctor-lint
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
rebuild: down build-nocache run wait-healthy doctor-lint

# restart — Stop and restart services. Data is preserved.
.PHONY: restart
restart: down run wait-healthy
	@echo ""
	@echo "Restart complete — system is running."

# reset — Destroy everything (volumes, state) and re-initialize.
#   Use to start completely fresh.
.PHONY: reset
reset: clean init

# run — Start all services.
.PHONY: run
run:
	$(DOCKER_COMPOSE) up -d