# ============================================================================
# n8n Production Deployment - Makefile
# ============================================================================
# Created by: David Nagtzaam - https://davidnagtzaam.com
#
# Quick reference:
#   make help          Show this help message
#   make init          Interactive setup wizard
#   make up            Start with external database
#   make up-local      Start with local PostgreSQL
#   make down          Stop all services
#   make restart       Restart all services
#   make logs          Follow all logs
#   make status        Show service status
#   make upgrade       Upgrade n8n to latest version
#   make backup        Create backup
#   make restore       Restore from backup
# ============================================================================

.PHONY: help init preflight up up-local down restart logs logs-web logs-worker logs-traefik status ps upgrade backup restore clean scale-workers health shell-web shell-worker shell-postgres install-man uninstall-man

# Default target
.DEFAULT_GOAL := help

# Variables
COMPOSE := docker compose
COMPOSE_LOCAL := docker compose -f compose.yaml -f compose.local-db.yaml

# ============================================================================
# HELP
# ============================================================================
help: ## Show this help message
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "n8n Production Deployment"
	@echo "By David Nagtzaam - https://davidnagtzaam.com"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "Available commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ============================================================================
# INSTALLATION & SETUP
# ============================================================================
preflight: ## Check system requirements
	@echo "Running preflight checks..."
	@bash scripts/preflight.sh

init: preflight ## Run interactive setup wizard
	@echo "Starting interactive setup..."
	@sudo bash scripts/init.sh

# ============================================================================
# SERVICE MANAGEMENT
# ============================================================================
up: ## Start services (external database)
	@echo "Starting n8n with external database..."
	@$(COMPOSE) up -d
	@echo ""
	@echo "✅ n8n is starting up!"
	@echo "Access your instance at: https://$$(grep N8N_HOST .env | cut -d '=' -f2)"
	@echo ""
	@echo "View logs: make logs"
	@echo "Check status: make status"

up-local: ## Start services (local PostgreSQL)
	@echo "Starting n8n with local PostgreSQL..."
	@$(COMPOSE_LOCAL) up -d
	@echo ""
	@echo "✅ n8n is starting up!"
	@echo "⏳ Local PostgreSQL may take 30 seconds to initialize..."
	@echo "Access your instance at: https://$$(grep N8N_HOST .env | cut -d '=' -f2)"
	@echo ""
	@echo "View logs: make logs"
	@echo "Check status: make status"

down: ## Stop all services
	@echo "Stopping n8n services..."
	@$(COMPOSE_LOCAL) down || $(COMPOSE) down
	@echo "✅ All services stopped"

restart: ## Restart all services
	@echo "Restarting n8n services..."
	@$(COMPOSE_LOCAL) restart || $(COMPOSE) restart
	@echo "✅ Services restarted"

# ============================================================================
# LOGS & MONITORING
# ============================================================================
logs: ## Follow logs for all services
	@$(COMPOSE_LOCAL) logs -f --tail=100 || $(COMPOSE) logs -f --tail=100

logs-web: ## Follow n8n-web logs
	@$(COMPOSE) logs -f n8n-web

logs-worker: ## Follow n8n-worker logs
	@$(COMPOSE) logs -f n8n-worker

logs-traefik: ## Follow Traefik logs
	@$(COMPOSE) logs -f traefik

status: ## Show service status
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Service Status"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@$(COMPOSE_LOCAL) ps || $(COMPOSE) ps
	@echo ""
	@echo "Health checks:"
	@bash scripts/healthcheck.sh

ps: status ## Alias for status

health: ## Run comprehensive health checks
	@bash scripts/healthcheck.sh

# ============================================================================
# MAINTENANCE
# ============================================================================
upgrade: ## Upgrade n8n to latest version
	@echo "Upgrading n8n..."
	@sudo bash scripts/upgrade.sh

backup: ## Create backup
	@echo "Creating backup..."
	@sudo bash scripts/backup.sh

restore: ## Restore from backup (usage: make restore BACKUP=backup-file.tgz)
	@if [ -z "$(BACKUP)" ]; then \
		echo "❌ Error: Please specify BACKUP=backup-file.tgz"; \
		exit 1; \
	fi
	@echo "Restoring from $(BACKUP)..."
	@sudo bash scripts/restore.sh $(BACKUP)

# ============================================================================
# SCALING
# ============================================================================
scale-workers: ## Scale workers (usage: make scale-workers COUNT=3)
	@if [ -z "$(COUNT)" ]; then \
		echo "❌ Error: Please specify COUNT=N (e.g., make scale-workers COUNT=3)"; \
		exit 1; \
	fi
	@echo "Scaling workers to $(COUNT) replicas..."
	@$(COMPOSE) up -d --scale n8n-worker=$(COUNT)
	@echo "✅ Scaled to $(COUNT) workers"

# ============================================================================
# DEBUGGING & SHELL ACCESS
# ============================================================================
shell-web: ## Open shell in n8n-web container
	@$(COMPOSE) exec n8n-web sh

shell-worker: ## Open shell in n8n-worker container
	@$(COMPOSE) exec n8n-worker sh

shell-postgres: ## Open PostgreSQL shell (local DB only)
	@$(COMPOSE_LOCAL) exec postgres psql -U $$(grep POSTGRES_USER .env | cut -d '=' -f2) -d $$(grep POSTGRES_DB .env | cut -d '=' -f2)

# ============================================================================
# CLEANUP
# ============================================================================
clean: ## Remove stopped containers and unused volumes
	@echo "Cleaning up..."
	@docker compose down -v
	@docker system prune -f
	@echo "✅ Cleanup complete"

clean-all: ## DANGER: Remove all data including volumes
	@echo "⚠️  WARNING: This will delete ALL data including databases and volumes!"
	@echo "Press Ctrl+C to cancel, or wait 10 seconds to continue..."
	@sleep 10
	@$(COMPOSE_LOCAL) down -v || $(COMPOSE) down -v
	@docker volume rm n8n-postgres-data n8n-redis-data n8n-traefik-acme n8n-traefik-logs 2>/dev/null || true
	@echo "✅ All data removed"

# ============================================================================
# DEVELOPMENT & TESTING
# ============================================================================
validate: ## Validate configuration files
	@echo "Validating Docker Compose configuration..."
	@$(COMPOSE) config > /dev/null && echo "✅ compose.yaml is valid"
	@$(COMPOSE_LOCAL) config > /dev/null && echo "✅ compose.local-db.yaml is valid"
	@echo "Validating environment file..."
	@test -f .env && echo "✅ .env exists" || echo "❌ .env missing"

pull: ## Pull latest Docker images
	@echo "Pulling latest images..."
	@$(COMPOSE) pull

# ============================================================================
# INFORMATION
# ============================================================================
version: ## Show n8n version
	@$(COMPOSE) exec n8n-web n8n --version || echo "Service not running"

info: ## Show deployment information
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "n8n Deployment Information"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@test -f .env && cat .env | grep -E '^(N8N_HOST|N8N_PROTOCOL|EXECUTIONS_MODE|DATABASE_URL|POSTGRES_HOST)' || echo ".env not found"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ============================================================================
# MANUAL PAGES
# ============================================================================
install-man: ## Install man pages (requires sudo)
	@echo "Installing man pages..."
	@sudo mkdir -p /usr/local/share/man/man1
	@sudo cp man/man1/n8nctl.1 /usr/local/share/man/man1/
	@sudo chmod 644 /usr/local/share/man/man1/n8nctl.1
	@sudo mandb 2>/dev/null || sudo makewhatis 2>/dev/null || true
	@echo "✅ Man pages installed"
	@echo "   View with: man n8nctl"

uninstall-man: ## Uninstall man pages (requires sudo)
	@echo "Removing man pages..."
	@sudo rm -f /usr/local/share/man/man1/n8nctl.1
	@sudo mandb 2>/dev/null || sudo makewhatis 2>/dev/null || true
	@echo "✅ Man pages removed"
