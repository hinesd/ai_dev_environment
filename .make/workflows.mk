# reconfigure — Apply openclaw.patch.json5 changes without rebuilding.
#   Use when you only edit services/openclaw/openclaw.patch.json5.
.PHONY: reconfigure
reconfigure: configure wait-healthy
	@echo ""
	@echo "Reconfigure complete — gateway is healthy."

# restart — Stop and restart services. Data is preserved.
.PHONY: restart
restart: down run wait-healthy
	@echo ""
	@echo "Restart complete — system is running."

# reset — Destroy everything (volumes, state) and re-initialize.
#   Use to start completely fresh.
.PHONY: reset
reset: clean init
