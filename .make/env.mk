include settings
-include .env

ifeq ($(DEBUG),true)
  OPENCLAW_DEFAULT_MODEL  := ollama/qwen2.5:7b
  OPENCLAW_PATCH          := openclaw.patch.local.json5
  COMPOSE_PROFILE         := --profile local-llm
  CONFIGURE_REPLACE_PATHS := --replace-path 'models.providers.ollama.models'
else ifeq ($(DEBUG),false)
  OPENCLAW_DEFAULT_MODEL  := deepseek/deepseek-chat
  OPENCLAW_PATCH          := openclaw.patch.cloud.json5
  COMPOSE_PROFILE         :=
  CONFIGURE_REPLACE_PATHS := --replace-path 'models.providers.deepseek.models'
else
  $(error DEBUG must be "true" or "false", got "$(DEBUG)")
endif

export OPENCLAW_DEFAULT_MODEL
export COMPOSE_PROFILE
export

.PHONY: verify_env
verify_env:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo ""; \
		echo ".env created from .env.example."; \
		echo "Fill in your values:"; \
		echo "  DUCKDNS_DOMAIN — your DuckDNS subdomain"; \
		echo "  DUCKDNS_TOKEN  — your DuckDNS API token"; \
		echo ""; \
		exit 1; \
	fi

.PHONY: gen_password
gen_password:
	@if ! grep -q "^OPENCLAW_GATEWAY_PASSWORD=.\{12,\}" .env 2>/dev/null; then \
		PASS=$$(openssl rand -hex 16); \
		sed -i '' "s|^OPENCLAW_GATEWAY_PASSWORD=.*|OPENCLAW_GATEWAY_PASSWORD=$$PASS|" .env; \
	fi
