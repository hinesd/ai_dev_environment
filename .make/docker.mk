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

.PHONY: model-pull
model-pull:
	@if [ -n "$(LOCAL_MODEL)" ]; then \
		docker model pull $(LOCAL_MODEL_ID); \
	else \
		echo "LOCAL_MODEL not set — skipping model pull"; \
	fi
