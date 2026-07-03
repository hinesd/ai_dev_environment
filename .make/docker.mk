.PHONY: build
build:
	$(DOCKER_COMPOSE) build

.PHONY: rebuild
rebuild:
	$(DOCKER_COMPOSE) build --no-cache --pull

.PHONY: up
up:
	$(DOCKER_COMPOSE) up -d

.PHONY: down
down:
	$(DOCKER_COMPOSE) down

.PHONY: clean
clean:
	$(DOCKER_COMPOSE) down -v

.PHONY: logs
logs:
	$(DOCKER_COMPOSE) logs -f

.PHONY: wait-healthy
wait-healthy:
	@echo "Waiting for gateway to be healthy..."
	@until docker compose exec -T openclaw-gateway curl -fsS http://127.0.0.1:18789/healthz > /dev/null 2>&1; do \
		echo "  waiting..."; sleep 2; \
	done
	@echo "Gateway is healthy."
