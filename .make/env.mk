DOCKER_COMPOSE := docker compose

include settings
include .env
export

.PHONY: verify_env
verify_env:
	@test -f .env || cp ".env.example" ".env"

.PHONY: gen_password
gen_password:
	@if ! grep -q "^OPENCLAW_GATEWAY_PASSWORD=.\{12,\}" .env 2>/dev/null; then \
		PASS=$$(openssl rand -hex 16); \
		sed -i "s|^OPENCLAW_GATEWAY_PASSWORD=.*|OPENCLAW_GATEWAY_PASSWORD=$$PASS|" .env; \
	fi
