# Convenience targets (Linux/macOS/CI). On Windows run the same
# `docker compose ...` commands directly - nothing else needs to be installed.
COMPOSE := docker compose
# Credentials for `make screenshots` (read from .env if present).
-include .env
GF_USER ?= $(or $(GF_SECURITY_ADMIN_USER),admin)
GF_PASS ?= $(or $(GF_SECURITY_ADMIN_PASSWORD),admin)

.PHONY: up down logs check test lint promtool amtool alloy screenshots

up:            ## start the whole stack
	$(COMPOSE) up -d

down:          ## stop the stack (keeps data volumes)
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f --tail=100

check: promtool amtool alloy lint test   ## everything CI runs

promtool:      ## validate prometheus.yml + all rule files
	$(COMPOSE) run --rm promtool check config /etc/prometheus/prometheus.yml

test:          ## unit-test recording & alerting rules
	$(COMPOSE) run --rm promtool test rules tests/slo_test.yml tests/domain_test.yml tests/api_usage_test.yml

lint:          ## PromQL lint with pint
	$(COMPOSE) run --rm pint

amtool:        ## validate alertmanager.yml
	$(COMPOSE) run --rm amtool

alloy:         ## validate the Alloy pipeline
	$(COMPOSE) run --rm alloy-validate

screenshots:   ## render dashboards (last 1 h) to docs/img via grafana-image-renderer
	for d in pp-home/planet-pulse:1350 pp-earthquakes/earthquakes:1450 pp-space/space-weather:1450 \
	         pp-weather/weather:1750 pp-slo/slo:2000 pp-api-usage/api-usage:1500; do \
	  uid=$${d%%/*}; path=$${d%%:*}; h=$${d##*:}; \
	  curl -sf -u "$(GF_USER):$(GF_PASS)" -o docs/img/$$uid.png \
	    "http://127.0.0.1:3000/render/d/$$path?from=now-1h&to=now&width=1600&height=$$h&kiosk=true&theme=dark&timeout=120"; \
	done
	# Platform: infra logs only (Grafana's own logs contain render URLs with tokens).
	curl -sf -u "$(GF_USER):$(GF_PASS)" -o docs/img/pp-platform.png \
	  "http://127.0.0.1:3000/render/d/pp-platform/platform?from=now-1h&to=now&width=1600&height=2350&kiosk=true&theme=dark&timeout=120&var-service=alloy&var-service=prometheus&var-service=json-exporter&var-service=loki"
