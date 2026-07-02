DOCKER_COMPOSE := docker compose

.PHONY: verify_env
verify_env:
	@test -f .env || cp ".env.example" ".env"
	@if ! grep -q "^OPENCLAW_GATEWAY_TOKEN=.\{16,\}" .env 2>/dev/null; then \
		TOKEN=$$(openssl rand -hex 24); \
		sed -i "s|^OPENCLAW_GATEWAY_TOKEN=.*|OPENCLAW_GATEWAY_TOKEN=$$TOKEN|" .env; \
	fi

.PHONY: build
build: verify_env
	$(DOCKER_COMPOSE) build

.PHONY: rebuild
rebuild: verify_env
	$(DOCKER_COMPOSE) build --no-cache --pull

.PHONY: onboarding
onboarding:
	$(DOCKER_COMPOSE) run --rm --no-deps --entrypoint node \
		-e OPENCLAW_GATEWAY_BIND=lan \
		-e OPENCLAW_DISABLE_BONJOUR=1 \
		openclaw-gateway \
		dist/index.js onboard --mode local --no-install-daemon

.PHONY: wait-healthy
wait-healthy:
	@echo "Waiting for gateway to be healthy..."
	@until curl -fsS http://127.0.0.1:18789/healthz > /dev/null 2>&1; do \
		echo "  waiting..."; sleep 2; \
	done
	@echo "Gateway is healthy."

.PHONY: configure
configure:
	$(DOCKER_COMPOSE) run --rm --no-deps --entrypoint node openclaw-gateway \
		dist/index.js config set --batch-json "$$(cat openclaw/seed.json)"
	$(DOCKER_COMPOSE) restart openclaw-gateway

.PHONY: setup
setup: rebuild up wait-healthy configure
	@echo ""
	@echo "OpenClaw gateway is ready."
	@echo "Run 'make token' to see the gateway token."
	@echo "Run 'make dashboard' to open the Control UI."

.PHONY: up
up:
	$(DOCKER_COMPOSE) up -d

.PHONY: run
run:
	$(DOCKER_COMPOSE) up

.PHONY: down
down:
	$(DOCKER_COMPOSE) down

.PHONY: logs
logs:
	$(DOCKER_COMPOSE) logs -f

.PHONY: dashboard
dashboard:
	$(DOCKER_COMPOSE) run --rm openclaw-cli dashboard --no-open

.PHONY: security-audit
security-audit:
	$(DOCKER_COMPOSE) run --rm openclaw-cli security audit $(ARGS)

.PHONY: token
token:
	$(DOCKER_COMPOSE) run --rm --no-deps --entrypoint node openclaw-gateway \
		dist/index.js config get gateway.auth.token

.PHONY: cli
cli:
	$(DOCKER_COMPOSE) run --rm openclaw-cli $(CMD)

.PHONY: channels
channels:
	$(DOCKER_COMPOSE) run --rm openclaw-cli channels $(CMD)

.PHONY: clean
clean:
	$(DOCKER_COMPOSE) down -v
