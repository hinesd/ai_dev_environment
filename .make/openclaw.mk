.PHONY: configure-seed
configure-seed:
	@echo "Seeding gateway config (DEBUG=$(DEBUG))..."
	@cat services/openclaw/$(OPENCLAW_PATCH) | $(OPENCLAW_RUN) config patch --stdin $(CONFIGURE_REPLACE_PATHS) --dry-run \
		&& cat services/openclaw/$(OPENCLAW_PATCH) | $(OPENCLAW_RUN) config patch --stdin $(CONFIGURE_REPLACE_PATHS) \
		&& $(OPENCLAW_RUN) config validate

.PHONY: configure
configure:
	@echo "Validating gateway config (DEBUG=$(DEBUG))..."
	@$(OPENCLAW) config patch --file /etc/openclaw/$(OPENCLAW_PATCH) $(CONFIGURE_REPLACE_PATHS) --dry-run \
		&& echo "Applying gateway config..." \
		&& $(OPENCLAW) config patch --file /etc/openclaw/$(OPENCLAW_PATCH) $(CONFIGURE_REPLACE_PATHS) \
		&& echo "Validating..." \
		&& $(OPENCLAW) config validate \
		&& echo "Restarting services..." \
		&& $(DOCKER_COMPOSE) restart openclaw-gateway \
		&& sleep 2 \
		&& $(DOCKER_COMPOSE) restart openclaw-caddy

.PHONY: llm
llm:
	@if [ "$(DEBUG)" != "true" ]; then echo "DEBUG=$(DEBUG) — set DEBUG=true to use local LLM"; exit 1; fi
	$(DOCKER_COMPOSE) --profile local-llm up -d ollama
	$(DOCKER_COMPOSE) exec -T ollama ollama pull qwen2.5:7b

.PHONY: llm-model-pull
llm-model-pull:
ifeq ($(DEBUG),true)
	@echo "Starting Ollama and pulling model..."
	$(DOCKER_COMPOSE) --profile local-llm up -d ollama
	@echo "Waiting for Ollama to be ready..."
	@until $(DOCKER_COMPOSE) exec -T ollama ollama list > /dev/null 2>&1; do \
		echo "  waiting..."; sleep 2; \
	done
	@echo "Pulling model..."
	$(DOCKER_COMPOSE) exec -T ollama ollama pull qwen2.5:7b
else
	@echo "DEBUG=false — skipping local model pull"
endif

.PHONY: qr
qr:
	$(OPENCLAW) qr --password "$(OPENCLAW_GATEWAY_PASSWORD)" --url wss://$(DUCKDNS_DOMAIN)

.PHONY: devices-list
devices-list:
	$(OPENCLAW) devices list --password "$(OPENCLAW_GATEWAY_PASSWORD)"

.PHONY: devices-approve
devices-approve:
	$(OPENCLAW) devices approve $(REQ) --password "$(OPENCLAW_GATEWAY_PASSWORD)"

.PHONY: nodes-approve
nodes-approve:
	$(OPENCLAW) nodes approve $(REQ)

.PHONY: nodes-status
nodes-status:
	$(OPENCLAW) nodes status

.PHONY: devices-pending
devices-pending:
	@$(OPENCLAW) devices list --json | \
		python3 -c 'import json,sys; data=json.load(sys.stdin); [print("make devices-approve REQ="+p["requestId"]) for p in data.get("pending",[])]'

.PHONY: nodes-pending
nodes-pending:
	@$(OPENCLAW) nodes pending --json | \
		python3 -c 'import json,sys; [print("make nodes-approve REQ="+p["requestId"]) for p in json.load(sys.stdin)]'

.PHONY: security-audit
security-audit:
	$(OPENCLAW) security audit $(ARGS)

.PHONY: doctor-lint
doctor-lint:
	$(OPENCLAW) doctor --lint

.PHONY: doctor-fix
doctor-fix:
	$(OPENCLAW) doctor --fix
