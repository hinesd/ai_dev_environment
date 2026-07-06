include environment/.env.network
-include environment/.env.secrets
export

.PHONY: verify_env
verify_env:
	@if [ ! -f environment/.env ]; then \
		cp environment/.env.example environment/.env; \
		echo ""; \
		echo "environment/.env created from .env.example."; \
		echo "Edit MODEL_DEFAULT to switch providers."; \
		echo ""; \
		exit 1; \
	fi
	@if [ ! -f environment/.env.secrets ]; then \
		cp environment/.env.secrets.example environment/.env.secrets; \
		echo ""; \
		echo "environment/.env.secrets created from .env.secrets.example."; \
		echo "Fill in your values:"; \
		echo "  DUCKDNS_DOMAIN — your DuckDNS subdomain"; \
		echo "  DUCKDNS_TOKEN  — your DuckDNS API token"; \
		echo "  DEEPSEEK_API_KEY — your DeepSeek API key"; \
		echo ""; \
		exit 1; \
	fi

.PHONY: gen_password
gen_password:
	@if ! grep -q "^OPENCLAW_GATEWAY_PASSWORD=.\{12,\}" environment/.env.secrets 2>/dev/null; then \
		PASS=$$(openssl rand -hex 16); \
		sed -i '' "s|^OPENCLAW_GATEWAY_PASSWORD=.*|OPENCLAW_GATEWAY_PASSWORD=$$PASS|" environment/.env.secrets; \
	fi
