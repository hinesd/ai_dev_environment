.PHONY: build
build:
	$(DOCKER_COMPOSE) build

.PHONY: build-nocache
build-nocache:
	$(DOCKER_COMPOSE) build --no-cache --pull

.PHONY: down
down:
	$(DOCKER_COMPOSE) down --remove-orphans

.PHONY: clean
clean:
	$(DOCKER_COMPOSE) down -v

.PHONY: logs
logs:
	$(DOCKER_COMPOSE) logs -f

.PHONY: wait-healthy
wait-healthy:
	@echo "Waiting for gateway to be healthy..."
	@until $(DOCKER_COMPOSE) exec -T openclaw-gateway curl -fsS http://127.0.0.1:$(OPENCLAW_GATEWAY_PORT)/healthz > /dev/null 2>&1; do \
		echo "  waiting..."; sleep 2; \
	done
	@echo "Gateway is healthy."
