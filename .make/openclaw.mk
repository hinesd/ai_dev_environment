.PHONY: configure
configure:
	$(DOCKER_COMPOSE) run --rm --no-deps --entrypoint node openclaw-gateway \
		dist/index.js config unset gateway.auth.token || true
	$(DOCKER_COMPOSE) run --rm --no-deps --entrypoint node openclaw-gateway \
		dist/index.js config unset gateway.auth.password || true
	$(DOCKER_COMPOSE) run --rm --no-deps --entrypoint node openclaw-gateway \
		dist/index.js config set --batch-json "$$(cat config/seed.json)"
	$(DOCKER_COMPOSE) restart openclaw-gateway

.PHONY: qr
qr:
	docker compose exec -T openclaw-gateway \
		node dist/index.js qr --password "$(OPENCLAW_GATEWAY_PASSWORD)" --url wss://openclaw.home

.PHONY: devices-list
devices-list:
	docker compose exec -T openclaw-gateway \
		node dist/index.js devices list --password "$(OPENCLAW_GATEWAY_PASSWORD)"

.PHONY: devices-approve
devices-approve:
	docker compose exec -T openclaw-gateway \
		node dist/index.js devices approve $(REQ) --password "$(OPENCLAW_GATEWAY_PASSWORD)"

.PHONY: onboarding
onboarding:
	$(DOCKER_COMPOSE) run --rm --no-deps --entrypoint node \
		-e OPENCLAW_GATEWAY_BIND=lan \
		-e OPENCLAW_DISABLE_BONJOUR=1 \
		openclaw-gateway \
		dist/index.js onboard --mode local --no-install-daemon

.PHONY: nodes-approve
nodes-approve:
	docker compose exec -T openclaw-gateway \
		node dist/index.js nodes approve $(REQ)

.PHONY: nodes-status
nodes-status:
	docker compose exec -T openclaw-gateway \
		node dist/index.js nodes status

.PHONY: nodes-pending
nodes-pending:
	@docker compose exec -T openclaw-gateway \
		node dist/index.js nodes pending --json | \
		python3 -c 'import json,sys; [print("make nodes-approve REQ="+p["requestId"]) for p in json.load(sys.stdin)]'

.PHONY: security-audit
security-audit:
	docker compose exec -T openclaw-gateway \
		node dist/index.js security audit $(ARGS)

.PHONY: cli
cli:
	docker compose exec -T openclaw-gateway \
		node dist/index.js $(CMD)

.PHONY: channels
channels:
	docker compose exec -T openclaw-gateway \
		node dist/index.js channels $(CMD)

.PHONY: dashboard
dashboard:
	docker compose exec -T openclaw-gateway \
		node dist/index.js dashboard
