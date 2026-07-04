include .make/env.mk
include .make/docker.mk
include .make/openclaw.mk

.PHONY: setup
setup: rebuild up wait-healthy configure
	@echo ""
	@echo "OpenClaw gateway is ready."
	@echo "Visit https://$(DUCKDNS_DOMAIN) for the Control UI."
	@echo "Auth is delegated to Caddy (trusted-proxy mode via X-Forwarded-User)."

.PHONY: init
init: verify_env gen_password down rebuild up wait-healthy configure
	@echo ""
	@echo "First-time setup complete."
	@echo "Next steps:"
	@echo "  1. Visit https://$(DUCKDNS_DOMAIN)"
	@echo "  2. Approve the browser: make devices-pending && make devices-approve REQ=<id>"

.PHONY: restart
restart: down up

.PHONY: reset
reset: clean init
