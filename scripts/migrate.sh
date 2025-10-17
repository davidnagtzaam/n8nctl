#!/usr/bin/env bash
# =============================================================================
# n8n Production Deployment - Safe Migration Script
# =============================================================================
# Description: Handles safe version upgrades with automatic backups and rollback
# Author: David Nagtzaam
# Version: 1.0.0
# =============================================================================

set -euo pipefail

# Load shared UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/lib-ui.sh"

# Variables
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
BACKUP_FILE="/tmp/n8n-pre-migration-$TIMESTAMP.tgz"
ROLLBACK_INFO="/tmp/n8n-migration-$TIMESTAMP.json"

# =============================================================================
# Pre-Migration Functions
# =============================================================================

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if n8n is running
    cd "$PROJECT_ROOT"
    if ! docker compose ps --format json &> /dev/null; then
        print_error "n8n is not running"
        echo "  ${SYMBOL_INFO} Start with: docker compose up -d"
        exit 1
    fi
    
    print_success "n8n is running"
    
    # Check disk space
    local available=$(df -BG "$PROJECT_ROOT" | tail -1 | awk '{print $4}' | tr -d 'G')
    if [ "$available" -lt 5 ]; then
        print_warn "Low disk space: ${available}GB available"
        echo "  ${SYMBOL_INFO} Recommended: At least 5GB free"
    else
        print_success "Sufficient disk space: ${available}GB available"
    fi
}

get_current_version() {
    print_header "Detecting Current Version"
    
    cd "$PROJECT_ROOT"
    
    local version=$(docker compose exec -T n8n-web n8n --version 2>/dev/null | head -1 || echo "unknown")
    
    if [ "$version" = "unknown" ]; then
        print_warn "Could not detect current version"
        return 1
    else
        print_info "Current version: $version"
        echo "$version" > "/tmp/n8n-version-before-$TIMESTAMP.txt"
        return 0
    fi
}

create_pre_migration_backup() {
    print_header "Creating Pre-Migration Backup"
    
    print_info "This backup can be used to rollback if migration fails"
    echo ""
    
    # Run backup script
    if [ -f "$SCRIPT_DIR/backup.sh" ]; then
        bash "$SCRIPT_DIR/backup.sh"
        
        # Find the most recent backup
        local latest_backup=$(ls -t /tmp/n8n-backup-*.tgz 2>/dev/null | head -1)
        
        if [ -n "$latest_backup" ]; then
            # Copy it to our migration backup location
            cp "$latest_backup" "$BACKUP_FILE"
            print_success "Pre-migration backup created: $BACKUP_FILE"
            
            # Store rollback information
            cat > "$ROLLBACK_INFO" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "backup_file": "$BACKUP_FILE",
  "original_backup": "$latest_backup",
  "migration_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
            return 0
        else
            print_error "Backup failed - no backup file created"
            return 1
        fi
    else
        print_error "Backup script not found"
        return 1
    fi
}

confirm_migration() {
    print_header "Migration Confirmation"
    
    print_warn "This will upgrade n8n to the latest version"
    echo ""
    print_info "The following will happen:"
    echo "  1. Services will be stopped"
    echo "  2. Docker images will be updated"
    echo "  3. Database migrations will run automatically"
    echo "  4. Services will be restarted"
    echo ""
    print_info "A backup has been created at:"
    echo "  ${SYMBOL_ARROW} $BACKUP_FILE"
    echo ""
    
    if ! prompt_yes_no "Proceed with migration?" "n"; then
        print_info "Migration cancelled"
        exit 0
    fi
}

# =============================================================================
# Migration Functions
# =============================================================================

stop_services() {
    print_header "Stopping Services"
    
    cd "$PROJECT_ROOT"
    
    print_info "Stopping n8n services gracefully..."
    
    if docker compose ps 2>/dev/null | grep -q "postgres"; then
        docker compose -f compose.yaml -f compose.local-db.yaml down
    else
        docker compose down
    fi
    
    print_success "Services stopped"
}

pull_latest_images() {
    print_header "Pulling Latest Images"
    
    cd "$PROJECT_ROOT"
    
    print_info "Downloading latest n8n image..."
    
    if docker compose pull; then
        print_success "Latest images downloaded"
        return 0
    else
        print_error "Failed to pull images"
        return 1
    fi
}

start_services() {
    print_header "Starting Services"
    
    cd "$PROJECT_ROOT"
    
    print_info "Starting services with new version..."
    
    # Start services
    if docker compose ps 2>/dev/null | grep -q "postgres" || [ -f "compose.local-db.yaml" ]; then
        docker compose -f compose.yaml -f compose.local-db.yaml up -d
    else
        docker compose up -d
    fi
    
    print_success "Services started"
}

wait_for_healthy() {
    print_header "Waiting for Services"
    
    print_info "Waiting for n8n to be ready (this may take a few minutes)..."
    echo ""
    
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker compose exec -T n8n-web wget -q --spider http://localhost:5678/healthz 2>/dev/null; then
            echo ""
            print_success "n8n is ready and healthy"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "${SYMBOL_PENDING}"
        sleep 2
    done
    
    echo ""
    print_error "n8n did not become healthy within expected time"
    return 1
}

verify_migration() {
    print_header "Verifying Migration"
    
    cd "$PROJECT_ROOT"
    
    # Check version
    local new_version=$(docker compose exec -T n8n-web n8n --version 2>/dev/null | head -1 || echo "unknown")
    
    if [ "$new_version" = "unknown" ]; then
        print_error "Could not verify new version"
        return 1
    else
        print_info "New version: $new_version"
    fi
    
    # Check if API is responding
    if docker compose exec -T n8n-web wget -q --spider http://localhost:5678/healthz 2>/dev/null; then
        print_success "API is responding"
    else
        print_error "API is not responding"
        return 1
    fi
    
    # Check database connection
    if docker compose logs n8n-web 2>/dev/null | grep -i "successfully connected to database" &> /dev/null; then
        print_success "Database connection verified"
    else
        print_info "Database connection status unclear (check logs)"
    fi
    
    # Check for any errors in recent logs
    local errors=$(docker compose logs --tail=50 n8n-web 2>/dev/null | grep -i "error" | wc -l)
    
    if [ "$errors" -gt 0 ]; then
        print_warn "Found $errors error messages in recent logs"
        echo "  ${SYMBOL_INFO} Review with: docker compose logs n8n-web"
    else
        print_success "No errors in recent logs"
    fi
    
    return 0
}

# =============================================================================
# Rollback Functions
# =============================================================================

offer_rollback() {
    echo ""
    print_header "Migration Issues Detected"
    
    print_warn "The migration may not have completed successfully"
    echo ""
    print_info "You can:"
    echo "  1. Continue anyway (check logs and verify manually)"
    echo "  2. Rollback to previous version (restore from backup)"
    echo ""
    
    if prompt_yes_no "Attempt automatic rollback?" "n"; then
        perform_rollback
    else
        print_info "Continuing without rollback"
        show_manual_rollback_instructions
    fi
}

perform_rollback() {
    print_header "Performing Rollback"
    
    print_warn "Rolling back to pre-migration state..."
    echo ""
    
    # Stop current services
    print_info "Stopping services..."
    cd "$PROJECT_ROOT"
    docker compose down
    
    # Restore from backup
    if [ -f "$BACKUP_FILE" ]; then
        print_info "Restoring from backup: $BACKUP_FILE"
        
        if [ -f "$SCRIPT_DIR/restore.sh" ]; then
            bash "$SCRIPT_DIR/restore.sh" "$BACKUP_FILE"
            print_success "Rollback completed"
        else
            print_error "Restore script not found"
            show_manual_rollback_instructions
        fi
    else
        print_error "Backup file not found: $BACKUP_FILE"
        show_manual_rollback_instructions
    fi
}

show_manual_rollback_instructions() {
    echo ""
    print_info "Manual rollback instructions:"
    echo ""
    echo "  1. Stop services:"
    echo "     cd $PROJECT_ROOT"
    echo "     docker compose down"
    echo ""
    echo "  2. Restore from backup:"
    echo "     sudo bash scripts/restore.sh $BACKUP_FILE"
    echo ""
    echo "  3. Or pull previous version:"
    echo "     Edit compose.yaml and change image version"
    echo "     docker compose up -d"
    echo ""
}

# =============================================================================
# Cleanup
# =============================================================================

cleanup_old_backups() {
    print_header "Cleanup"
    
    # Keep migration backups separate from regular backups
    local migration_backups=$(ls -t /tmp/n8n-pre-migration-*.tgz 2>/dev/null | wc -l)
    
    if [ "$migration_backups" -gt 5 ]; then
        print_info "Removing old migration backups (keeping 5 most recent)..."
        ls -t /tmp/n8n-pre-migration-*.tgz 2>/dev/null | tail -n +6 | xargs -r rm -f
        print_success "Old migration backups cleaned up"
    else
        print_info "Migration backup count within limits: $migration_backups"
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    clear
    print_banner "n8n Safe Migration Tool" "Version 1.0.0"
    
    echo ""
    
    # Pre-migration checks
    check_prerequisites
    echo ""
    get_current_version || true
    echo ""
    create_pre_migration_backup
    echo ""
    confirm_migration
    echo ""
    
    # Perform migration
    stop_services
    echo ""
    
    if ! pull_latest_images; then
        print_error "Failed to pull images - aborting migration"
        print_info "Services are stopped. Restart with: docker compose up -d"
        exit 1
    fi
    echo ""
    
    start_services
    echo ""
    wait_for_healthy
    echo ""
    
    # Verify migration
    if ! verify_migration; then
        offer_rollback
        exit 1
    fi
    echo ""
    
    # Cleanup
    cleanup_old_backups
    echo ""
    
    # Success summary
    print_header "Migration Complete"
    echo ""
    print_success "n8n has been successfully upgraded"
    echo ""
    print_info "Useful commands:"
    echo "  ${SYMBOL_ARROW} View logs:      docker compose logs -f n8n-web"
    echo "  ${SYMBOL_ARROW} Check status:   docker compose ps"
    echo "  ${SYMBOL_ARROW} Run tests:      bash scripts/test.sh"
    echo ""
    print_info "Migration backup saved at:"
    echo "  ${SYMBOL_ARROW} $BACKUP_FILE"
    echo ""
    print_info "Keep this backup for a few days in case rollback is needed"
    echo ""
}

# Check if running as root for Docker access
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root or with sudo"
    exit 1
fi

main "$@"
