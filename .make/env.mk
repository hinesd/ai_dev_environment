export

.PHONY: verify_env
verify_env:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo ""; \
		echo ".env created from .env.example."; \
		echo ""; \
		exit 1; \
	fi
