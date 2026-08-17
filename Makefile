.DEFAULT_GOAL := help

COMPOSE      := docker compose
C_OBS        := docker compose -f docker-compose.yml -f docker-compose.obs.yml
C_VAULT      := docker compose -f docker-compose.yml -f docker-compose.vault.yml
C_SONAR      := docker compose -f docker-compose.yml -f docker-compose.sonar.yml
C_SEC        := docker compose -f docker-compose.yml -f docker-compose.security.yml
C_EGRESS     := docker compose -f docker-compose.yml -f docker-compose.egress.yml
C_ALL        := docker compose -f docker-compose.yml -f docker-compose.obs.yml -f docker-compose.vault.yml -f docker-compose.security.yml

help: ## Show this help
	@echo "Daig - DevOps intern rotation teaching platform"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
	  awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Read VERIFICATION.md before trusting any of this."

# ---------------------------------------------------------------- core
up: ## Start the three application tiers
	$(COMPOSE) up -d --build
	@echo "web http://localhost:8080"

down: ## Stop everything, keep volumes
	$(C_ALL) down

nuke: ## Stop everything and DELETE volumes (including the database)
	$(C_ALL) down -v

logs: ## Tail all logs
	$(C_ALL) logs -f --tail=80

ps: ## Show what is running
	$(C_ALL) ps

seed: ## Load restaurants and menu items
	./scripts/seed.sh

smoke: ## Verify every tier answers
	./scripts/smoke.sh

psql: ## Open a shell on the database
	$(COMPOSE) exec postgres psql -U daig -d daig

# ---------------------------------------------------------------- observability
obs: ## Start with the observability stack
	$(C_OBS) up -d --build
	@echo "grafana http://localhost:3000  (admin / CHANGE_ME_DEV_ONLY)"

load: ## Simulate the iftar spike
	node load/iftar-spike.js

load-spike: ## Peak load only, for the Day 4 exercise
	PROFILE=spike node load/iftar-spike.js

# ---------------------------------------------------------------- vault
vault-up: ## Start OpenBao, initialise, unseal, provision
	$(C_VAULT) up -d openbao
	@echo "waiting for OpenBao..."
	@sleep 8
	./vault/bootstrap.sh

vault-app: ## Run Daig with credentials from OpenBao
	@test -f vault/.approle/orders.env || { echo "run 'make vault-up' first"; exit 1; }
	$(C_VAULT) --env-file .env --env-file vault/.approle/orders.env up -d --force-recreate orders
	$(C_VAULT) --env-file .env --env-file vault/.approle/kitchen.env up -d --force-recreate kitchen
	$(C_VAULT) --env-file .env --env-file vault/.approle/dispatch.env up -d --force-recreate dispatch
	@sleep 4
	@echo "--- credential source ---"
	@$(COMPOSE) logs orders 2>/dev/null | grep -o '"credential_source":"[a-z]*"' | tail -1 || echo "check: docker compose logs orders"

vault-demo: ## Guided OpenBao walkthrough
	./vault/demo.sh

vault-ui: ## Print the UI URL and root token
	@echo "http://localhost:8200"
	@echo -n "root token: "
	@python3 -c "import json;print(json.load(open('vault/.init-keys.json'))['root_token'])" 2>/dev/null || echo "(not initialised - run make vault-up)"

vault-seal: ## Seal the vault (break-glass drill)
	$(C_VAULT) exec -T -e BAO_ADDR=http://127.0.0.1:8200 openbao bao operator seal

# ---------------------------------------------------------------- security
sonar: ## Start SonarQube (needs ~2GB RAM, 2-4 min to boot)
	$(C_SONAR) up -d
	@echo "sonarqube http://localhost:9000  (admin / admin)"

sec-up: ## Start the DevSecOps overlay (ZAP, Falco)
	$(C_SEC) up -d

scan: ## Run the whole security toolchain locally
	./security/scan-all.sh

scan-sast: ## SAST only (fastest useful gate)
	./security/scan-all.sh sast

dast: ## Run the OWASP ZAP baseline against the running stack
	$(C_SEC) --profile dast run --rm zap

egress-up: ## Start the forward proxy (Squid egress allow-list on :3128)
	$(C_EGRESS) up -d squid
	@echo "forward proxy on :3128 - allow-list in security/egress/squid.conf"

egress-test: ## Prove the egress allow-list (allowed=200, blocked=403)
	$(C_EGRESS) --profile test run --rm egress-test

insecure-on: ## Enable the six deliberate vulnerabilities
	./chaos/day6-security.sh break

insecure-off: ## Disable them
	./chaos/day6-security.sh fix

# ---------------------------------------------------------------- teaching
broken: ## Build the kickoff exercise image (exits 78)
	docker build --target broken -f services/orders/Dockerfile -t tkxel/daig-orders:broken .
	@echo "now run: docker run --rm tkxel/daig-orders:broken"

# ---------------------------------------------------------------- checks
check: ## Static checks - no Docker or network needed
	@echo "javascript..."
	@for f in $$(find services load scripts -name '*.js'); do node --check $$f || exit 1; done
	@echo "shell..."
	@for f in $$(find . -name '*.sh' -not -path './node_modules/*'); do bash -n $$f || exit 1; done
	@bash -n .githooks/pre-commit
	@echo "yaml..."
	@python3 -c "import yaml,glob,sys;\
	[list(yaml.safe_load_all(open(f))) for f in glob.glob('**/*.y*ml', recursive=True)]"
	@echo "json..."
	@python3 -c "import json,glob;[json.load(open(f)) for f in glob.glob('**/*.json', recursive=True) if 'node_modules' not in f]"
	@echo "all static checks passed"

test: ## Run unit tests
	@cd services/orders && npm test

fmt-check: ## Terraform format check
	@for d in infra/aws infra/gcp infra/azure; do terraform -chdir=$$d fmt -check -recursive || true; done

hooks: ## Install the pre-commit hook
	cp .githooks/pre-commit .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
	@echo "installed"

.PHONY: help up down nuke logs ps seed smoke psql obs load load-spike \
        vault-up vault-app vault-demo vault-ui vault-seal \
        sonar sec-up scan scan-sast dast egress-up egress-test insecure-on insecure-off \
        broken check test fmt-check hooks
