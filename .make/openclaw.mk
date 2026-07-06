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
	-$(OPENCLAW) doctor --lint	