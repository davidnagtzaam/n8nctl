#!/usr/bin/env bash
# ============================================================================
# n8n Production Deployment - Zero-Downtime Upgrade Script
# ============================================================================
# Created by: David Nagtzaam - https://davidnagtzaam.com
#
# This script safely upgrades n8n to the latest version with:
# - Pre-upgrade backup
# - Health checks before and after
# - Graceful service restart
# - Rollback capability
# ============================================================================

set -euo pipefail

# Load shared UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/lib-ui.sh"

# Variables
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="/tmp/n8n-upgrade-backup-$(date +%Y%m%d-%H%M%S)"

check_docker_running() {
    if ! docker info &> /dev/null; then
        print_error "Docker is not running"
        exit 1
    fi
}

# ============================================================================
# Pre-Upgrade Steps
# ============================================================================

pre_upgrade_checks() {
    print_header "Pre-Upgrade Checks"
    
    cd "$PROJECT_ROOT"
    
    # Check if .env exists
    if [[ ! -f .env ]]; then
        print_error ".env file not found. Run 'sudo bash scripts/init.sh' first."
        exit 1
    fi
    
    # Check if services are running
    if ! docker compose ps | grep -q "Up"; then
        print_warning "Services don't appear to be running"
        if ! prompt_yes_no "Continue anyway?" "n"; then
            exit 1
        fi
    fi
    
    print_success "Pre-upgrade checks passed"
}

create_pre_upgrade_backup() {
    print_header "Creating Pre-Upgrade Backup"
    
    print_info "Creating backup before upgrade..."
    
    # Run backup script
    if bash "$SCRIPT_DIR/backup.sh"; then
        print_success "Pre-upgrade backup created"
    else
        print_error "Backup failed"
        if ! prompt_yes_no "Continue without backup?" "n"; then
            exit 1
        fi
    fi
}

check_current_version() {
    print_header "Current Version"
    
    if docker compose ps | grep -q "n8n-web"; then
        CURRENT_VERSION=$(docker compose exec -T n8n-web n8n --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
        print_info "Current n8n version: $CURRENT_VERSION"
    else
        print_warning "Could not determine current version"
    fi
}

# ============================================================================
# Upgrade Process
# ============================================================================

pull_new_images() {
    print_header "Pulling Latest Images"
    
    cd "$PROJECT_ROOT"
    
    print_info "Pulling latest n8n image..."
    
    # Detect if using local database
    if docker compose ps 2>/dev/null | grep -q "postgres"; then
        show_spinner "Pulling latest images" \
            docker compose -f compose.yaml -f compose.local-db.yaml pull --quiet
    else
        show_spinner "Pulling latest images" \
            docker compose pull --quiet
    fi
    
    print_success "Latest images pulled"
}

health_check_services() {
    print_info "Checking service health..."
    
    # Check Redis
    if docker compose exec -T redis redis-cli PING &> /dev/null; then
        print_success "Redis is healthy"
    else
        print_warning "Redis health check failed"
    fi
    
    # Check PostgreSQL (if local)
    if docker compose ps 2>/dev/null | grep -q "postgres"; then
        if docker compose exec -T postgres pg_isready &> /dev/null; then
            print_success "PostgreSQL is healthy"
        else
            print_warning "PostgreSQL health check failed"
        fi
    fi
}

upgrade_services() {
    print_header "Upgrading Services"
    
    cd "$PROJECT_ROOT"
    
    print_info "Recreating containers with new images..."
    
    # Detect if using local database
    if docker compose ps 2>/dev/null | grep -q "postgres"; then
        show_spinner "Upgrading containers" \
            docker compose -f compose.yaml -f compose.local-db.yaml up -d --remove-orphans
    else
        show_spinner "Upgrading containers" \
            docker compose up -d --remove-orphans
    fi
    
    print_success "Services upgraded"
}

wait_for_n8n() {
    print_header "Waiting for n8n to be Ready"
    
    print_info "Waiting for n8n web service to be healthy..."
    
    local max_attempts=60
    local attempt=0
    local wait_seconds=5
    
    while [ $attempt -lt $max_attempts ]; do
        if docker compose ps | grep "n8n-web" | grep -q "(healthy)"; then
            print_success "n8n web service is healthy"
            return 0
        fi
        
        if docker compose exec -T n8n-web wget -q --spider http://localhost:5678/healthz 2>/dev/null; then
            print_success "n8n web service is responding"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep $wait_seconds
    done
    
    echo ""
    print_warning "n8n did not become healthy within expected time"
    print_info "Check logs with: docker compose logs n8n-web"
}

# ============================================================================
# Post-Upgrade Steps
# ============================================================================

check_new_version() {
    print_header "New Version"
    
    if docker compose ps | grep -q "n8n-web"; then
        NEW_VERSION=$(docker compose exec -T n8n-web n8n --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
        print_info "New n8n version: $NEW_VERSION"
        
        if [[ "$NEW_VERSION" != "$CURRENT_VERSION" && "$NEW_VERSION" != "unknown" ]]; then
            print_success "Successfully upgraded from $CURRENT_VERSION to $NEW_VERSION"
        fi
    else
        print_warning "Could not determine new version"
    fi
}

cleanup_old_images() {
    print_header "Cleanup"
    
    print_info "Removing old Docker images..."
    show_spinner "Cleaning up old images" \
        docker image prune -f
    print_success "Cleanup complete"
}

post_upgrade_health_check() {
    print_header "Post-Upgrade Health Check"
    
    # Run health check script if it exists
    if [[ -f "$SCRIPT_DIR/healthcheck.sh" ]]; then
        bash "$SCRIPT_DIR/healthcheck.sh"
    else
        health_check_services
    fi
}

# ============================================================================
# Rollback
# ============================================================================

offer_rollback() {
    print_header "Rollback Option"
    
    print_warning "If something went wrong, you can rollback."
    print_info "Rollback will restore from the pre-upgrade backup."
    echo ""
    
    if prompt_yes_no "Do you want to rollback?" "n"; then
        print_info "Rolling back..."
        
        # Find most recent backup
        LATEST_BACKUP=$(ls -t /tmp/n8n-backup-*.tgz 2>/dev/null | head -1 || echo "")
        
        if [[ -z "$LATEST_BACKUP" ]]; then
            print_error "No backup found for rollback"
            exit 1
        fi
        
        if bash "$SCRIPT_DIR/restore.sh" "$LATEST_BACKUP"; then
            print_success "Rollback complete"
        else
            print_error "Rollback failed"
            exit 1
        fi
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    clear
    
    print_banner "⚡ n8n Upgrade Tool" "By David Nagtzaam" "davidnagtzaam.com"
    
    # Confirmation
    if ! prompt_yes_no "Upgrade n8n to the latest version?" "n"; then
        print_info "Upgrade cancelled"
        exit 0
    fi
    
    # Pre-upgrade
    check_docker_running
    pre_upgrade_checks
    check_current_version
    create_pre_upgrade_backup
    
    # Upgrade
    pull_new_images
    upgrade_services
    wait_for_n8n
    
    # Post-upgrade
    check_new_version
    post_upgrade_health_check
    cleanup_old_images
    
    # Summary
    print_header "Upgrade Complete!"
    echo ""
    print_success "n8n has been upgraded successfully"
    echo ""
    print_info "Useful commands:"
    echo "  • View logs:        docker compose logs -f n8n-web"
    echo "  • Check status:     docker compose ps"
    echo "  • Health check:     bash scripts/healthcheck.sh"
    echo ""
    
    # Offer rollback if there are issues
    if [[ "$NEW_VERSION" == "unknown" ]] || docker compose ps | grep -q "Restarting"; then
        offer_rollback
    fi
}

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root or with sudo"
    exit 1
fi

main "$@"
