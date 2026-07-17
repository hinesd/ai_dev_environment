export

.PHONY: verify_env
verify_env:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo ""; \
		echo ".env created from .env.example — fill it in, then re-run."; \
		echo ""; \
		exit 1; \
	fi
	@if grep -q '^OPENCLAW_GATEWAY_PASSWORD=\(REPLACE_ME\)*$$' .env; then \
		echo "ERROR: OPENCLAW_GATEWAY_PASSWORD is not set in .env (still empty or REPLACE_ME)."; \
		exit 1; \
	fi
	@if [ "$(MODE)" = "lan" ] && ! grep -q '^DUCKDNS_DOMAIN=..*' .env; then \
		echo "ERROR: MODE=lan requires DUCKDNS_DOMAIN in .env."; \
		exit 1; \
	fi

# verify_ip — lan mode: fail fast if STATIC_IP is not bindable on this host,
# since compose would otherwise die with a cryptic bind error on 80/443.
# Tries an actual bind (what compose will do) rather than grepping ifconfig.
# No-op in local mode.
.PHONY: verify_ip
verify_ip:
	@if [ "$(MODE)" = "lan" ]; then \
		if ! python3 -c 'import socket; s=socket.socket(); s.bind(("$(STATIC_IP)", 0))' 2>/dev/null; then \
			echo "ERROR: cannot bind to STATIC_IP=$(STATIC_IP) on this host."; \
			echo "       The IP is not assigned to an active interface (wrong network,"; \
			echo "       DHCP change, or typo). Fix STATIC_IP in .env, or set"; \
			echo "       MODE=local to run without LAN exposure."; \
			exit 1; \
		fi; \
	fi
