export

.PHONY: verify_env
verify_env:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo ""; \
		echo ".env created from .env.example."; \
		echo "Edit MODEL_DEFAULT to switch providers."; \
		echo "Fill in DUCKDNS_DOMAIN, DUCKDNS_TOKEN, and DEEPSEEK_API_KEY."; \
		echo ""; \
		exit 1; \
	fi

.PHONY: gen_password
gen_password:
	@if ! grep -q "^OPENCLAW_GATEWAY_PASSWORD=.\{12,\}" .env 2>/dev/null; then \
		PASS=$$(openssl rand -hex 16); \
		sed -i '' "s|^OPENCLAW_GATEWAY_PASSWORD=.*|OPENCLAW_GATEWAY_PASSWORD=$$PASS|" .env; \
	fi
