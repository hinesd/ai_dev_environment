.PHONY: ollama-pull
ollama-pull:
	@if [ "$(findstring ollama,$(MODEL_DEFAULT))" = "" ]; then echo "MODEL_DEFAULT=$(MODEL_DEFAULT) — not ollama"; exit 1; fi
	$(DOCKER_COMPOSE) up -d ollama
	$(DOCKER_COMPOSE) exec -T ollama ollama pull qwen2.5:7b

.PHONY: ollama-model-pull
ollama-model-pull:
ifneq (,$(findstring ollama,$(MODEL_DEFAULT)))
	@echo "Starting Ollama and pulling model..."
	$(DOCKER_COMPOSE) up -d ollama
	@echo "Waiting for Ollama to be ready..."
	@until $(DOCKER_COMPOSE) exec -T ollama ollama list > /dev/null 2>&1; do \
		echo "  waiting..."; sleep 2; \
	done
	@echo "Pulling model..."
	$(DOCKER_COMPOSE) exec -T ollama ollama pull qwen2.5:7b
else
	@echo "MODEL_DEFAULT=$(MODEL_DEFAULT) — skipping ollama model pull"
endif
