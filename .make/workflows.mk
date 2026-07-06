# config — Apply idempotent patches to the running gateway.
#   Use when you edit src/openclaw/patches/*.json5.
.PHONY: reconfigure
reconfigure: config wait-healthy
	@echo ""
	@echo "Config applied — gateway is healthy."

# restart — Stop and restart services. Data is preserved.
.PHONY: restart
restart: down run wait-healthy
	@echo ""
	@echo "Restart complete — system is running."

# reset — Destroy everything (volumes, state) and re-initialize.
#   Use to start completely fresh.
.PHONY: reset
reset: clean init
