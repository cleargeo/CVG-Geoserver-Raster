# =============================================================================
# CVG GeoServer Raster — Operations Makefile
# (c) Clearview Geographic, LLC — Proprietary
# =============================================================================
# Usage (from project root on DFORGE-100 Git Bash or Linux):
#
#   make dev          Start local dev stack (portal on :80, GeoServer on :8080)
#   make stop         Stop and remove dev containers
#   make logs         Tail GeoServer logs (dev)
#   make shell        Shell into GeoServer container (dev)
#   make health       Run local health check
#
#   make deploy       Full production deploy (creates VM, bootstraps, deploys)
#   make redeploy     Quick redeploy (sync + rebuild + restart, skip VM creation)
#   make rebuild      Full rebuild with --no-cache (clean Docker layers)
#   make init         Run GeoServer first-run initialization via REST API
#   make backup       Backup GeoServer data_dir on prod VM
#   make health-prod  Run health check against production endpoints
#
#   make clean        Remove dev containers, volumes, and prune images
#   make image-info   Show current Docker image sizes
#   make status       Show all container status (dev)
#
# =============================================================================

.PHONY: dev stop logs shell health build \
        deploy redeploy rebuild init backup health-prod \
        clean prune image-info status help

# ── Config ────────────────────────────────────────────────────────────────────
COMPOSE        := docker compose
COMPOSE_PROD   := docker compose -f docker-compose.prod.yml
GS_CONTAINER   := geoserver-raster-dev
GS_CONTAINER_P := geoserver-raster
PROD_IP        := 10.10.10.203
PROD_USER      := ubuntu
SSH_KEY        := $(HOME)/.ssh/cvg_neuron_proxmox
SSH_OPTS       := -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o LogLevel=ERROR
PROJECT_DEST   := /opt/cvg/CVG_Geoserver_Raster
DOMAIN         := raster.cleargeo.tech

# ── Colors ───────────────────────────────────────────────────────────────────
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[1;33m
BLUE   := \033[0;34m
CYAN   := \033[0;36m
NC     := \033[0m

# ==============================================================================
# LOCAL DEVELOPMENT
# ==============================================================================

## Start the dev stack (portal at http://localhost, GeoServer direct on :8080)
dev:
	@echo -e "$(CYAN)Starting CVG GeoServer Raster dev stack...$(NC)"
	$(COMPOSE) up -d --build
	@echo ""
	@echo -e "$(GREEN)══ Dev stack running ══$(NC)"
	@echo -e "  Portal:      http://localhost/"
	@echo -e "  GeoServer:   http://localhost:8080/geoserver/web/"
	@echo -e "  Logs:        make logs"
	@echo -e "  Shell:       make shell"
	@echo -e "  Stop:        make stop"

## Build the Docker image without starting
build:
	@echo -e "$(CYAN)Building CVG GeoServer Raster image...$(NC)"
	$(COMPOSE) build

## Stop and remove dev containers (volumes preserved)
stop:
	@echo -e "$(YELLOW)Stopping dev stack...$(NC)"
	$(COMPOSE) down
	@echo -e "$(GREEN)Stopped$(NC)"

## Tail GeoServer logs (Ctrl+C to stop)
logs:
	$(COMPOSE) logs -f $(GS_CONTAINER)

## Tail ALL dev container logs
logs-all:
	$(COMPOSE) logs -f

## Tail Caddy dev logs
logs-caddy:
	$(COMPOSE) logs -f caddy

## Shell into the GeoServer container
shell:
	$(COMPOSE) exec $(GS_CONTAINER) bash

## Show dev container status
status:
	$(COMPOSE) ps
	@echo ""
	@echo "Docker volumes:"
	@docker volume ls --filter name=geoserver-raster 2>/dev/null || true

## Run local health check against dev stack
health:
	@bash scripts/health-check.sh --local

# ==============================================================================
# PRODUCTION OPERATIONS
# ==============================================================================

## Full first-time deploy (create VM → bootstrap → build → deploy)
deploy:
	@echo -e "$(CYAN)Starting full production deployment...$(NC)"
	@[ -f .env ] || (echo -e "$(YELLOW)WARNING: .env file not found — using defaults. Run: cp .env.example .env$(NC)" && sleep 2)
	bash deploy_production.sh

## Quick redeploy (sync + rebuild + restart, skip VM creation)
redeploy:
	@echo -e "$(CYAN)Redeploying to production VM ($(PROD_IP))...$(NC)"
	@[ -f .env ] || (echo -e "$(YELLOW)WARNING: .env file not found$(NC)" && sleep 2)
	bash deploy_production.sh --redeploy

## Full rebuild without Docker cache + redeploy
rebuild:
	@echo -e "$(YELLOW)Full rebuild with --no-cache (this may take 5-10 minutes)...$(NC)"
	bash deploy_production.sh --redeploy --no-cache

## Run GeoServer first-run initialization on production VM
init:
	@echo -e "$(CYAN)Running GeoServer Raster init on production ($(PROD_IP))...$(NC)"
	@[ -f .env ] || (echo -e "$(RED)ERROR: .env file not found. Run: cp .env.example .env$(NC)" && exit 1)
	ssh $(SSH_OPTS) -i $(SSH_KEY) $(PROD_USER)@$(PROD_IP) \
		"cd $(PROJECT_DEST) && docker compose -f docker-compose.prod.yml --profile init up geoserver-init"

## Backup GeoServer data_dir on production VM
backup:
	@echo -e "$(CYAN)Running data_dir backup on production VM...$(NC)"
	ssh $(SSH_OPTS) -i $(SSH_KEY) $(PROD_USER)@$(PROD_IP) \
		"cd $(PROJECT_DEST) && bash scripts/backup.sh"

## Tail GeoServer logs on production VM
logs-prod:
	ssh $(SSH_OPTS) -i $(SSH_KEY) $(PROD_USER)@$(PROD_IP) \
		"cd $(PROJECT_DEST) && docker compose -f docker-compose.prod.yml logs -f geoserver-raster"

## Shell into GeoServer container on production VM
shell-prod:
	ssh $(SSH_OPTS) -i $(SSH_KEY) $(PROD_USER)@$(PROD_IP) \
		"cd $(PROJECT_DEST) && docker compose -f docker-compose.prod.yml exec geoserver-raster bash"

## Show production container status
status-prod:
	ssh $(SSH_OPTS) -i $(SSH_KEY) $(PROD_USER)@$(PROD_IP) \
		"cd $(PROJECT_DEST) && docker compose -f docker-compose.prod.yml ps"

## Run health check against production endpoints
health-prod:
	@bash scripts/health-check.sh --prod

## Change admin password on production (interactive — reads GEOSERVER_ADMIN_PASSWORD from .env)
reset-password:
	@echo -e "$(CYAN)Resetting GeoServer admin password on production...$(NC)"
	@[ -f .env ] || (echo -e "$(RED)ERROR: .env file not found$(NC)" && exit 1)
	@bash scripts/reset-password.sh

# ==============================================================================
# MAINTENANCE
# ==============================================================================

## Remove dev containers and volumes (DATA LOSS WARNING)
clean:
	@echo -e "$(RED)WARNING: This will DELETE all dev volumes (GeoServer data, GWC cache)$(NC)"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || (echo "Aborted." && exit 1)
	$(COMPOSE) down --volumes --remove-orphans
	docker image rm cvg/geoserver-raster:dev 2>/dev/null || true
	@echo -e "$(GREEN)Clean complete$(NC)"

## Prune unused Docker images and build cache
prune:
	docker image prune -f
	docker builder prune -f

## Show Docker image sizes
image-info:
	@echo "Docker images:"
	@docker images | grep -E "REPOSITORY|geoserver-raster|caddy"

## Validate Caddyfile syntax
caddy-validate:
	@echo -e "$(CYAN)Validating Caddyfile...$(NC)"
	docker run --rm -v "$(shell pwd)/caddy/Caddyfile:/etc/caddy/Caddyfile:ro" caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile
	@echo -e "$(GREEN)Caddyfile OK$(NC)"

## Show disk usage on production VM
disk-prod:
	ssh $(SSH_OPTS) -i $(SSH_KEY) $(PROD_USER)@$(PROD_IP) \
		"df -h / /mnt/cgps /mnt/cgdp 2>/dev/null; echo '---'; docker system df"

# ==============================================================================
# HELP
# ==============================================================================

## Show this help
help:
	@echo ""
	@echo -e "$(CYAN)CVG GeoServer Raster — Makefile Operations$(NC)"
	@echo -e "$(CYAN)═══════════════════════════════════════════$(NC)"
	@grep -E '^##' Makefile | sed 's/## /  /' | sed 's/^/  /'
	@echo ""
	@echo -e "  $(YELLOW)Portal:$(NC)   https://$(DOMAIN)/"
	@echo -e "  $(YELLOW)Admin:$(NC)    https://$(DOMAIN)/geoserver/web/ (LAN only)"
	@echo ""

.DEFAULT_GOAL := help
