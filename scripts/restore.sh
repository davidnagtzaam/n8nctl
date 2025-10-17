#!/usr/bin/env bash
# ============================================================================
# n8n Production Deployment - Restore Script
# ============================================================================
# Created by: David Nagtzaam - https://davidnagtzaam.com
#
# This script restores n8n from a backup created by backup.sh
# Restores:
# - PostgreSQL database
# - Configuration files
# - Docker volumes
# ============================================================================

set -euo pipefail

# Load shared UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/lib-ui.sh"

# Variables
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESTORE_DIR="/tmp/n8n-restore-$(date +%Y%m%d-%H%M%S)"

# ============================================================================
# Validation
# ============================================================================

validate_backup_file() {
    local backup_file="$1"
    
    print_header "Validating Backup File"
    
    # Check if file exists
    if [[ ! -f "$backup_file" ]]; then
        print_error "Backup file not found: $backup_file"
        exit 1
    fi
    
    # Check if it's a valid tar.gz
    if ! tar tzf "$backup_file" &> /dev/null; then
        print_error "Invalid backup file format"
        exit 1
    fi
    
    print_success "Backup file is valid"
}

# ============================================================================
# Restore Functions
# ============================================================================

extract_backup() {
    local backup_file="$1"
    
    print_header "Extracting Backup"
    
    print_info "Extracting backup to: $RESTORE_DIR"
    mkdir -p "$RESTORE_DIR"
    
    tar xzf "$backup_file" -C "$RESTORE_DIR" --strip-components=1
    
    print_success "Backup extracted"
    
    # Show metadata if available
    if [[ -f "$RESTORE_DIR/metadata.txt" ]]; then
        echo ""
        print_info "Backup Metadata:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "$RESTORE_DIR/metadata.txt"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    fi
}

confirm_restore() {
    print_header "Confirmation Required"
    
    print_warning "WARNING: This will replace your current n8n data!"
    print_warning "All current workflows, credentials, and data will be lost!"
    echo ""
    print_info "It's recommended to create a backup of current state first."
    echo ""
    
    if ! prompt_yes_no "Continue with restore?" "n"; then
        print_info "Restore cancelled"
        exit 0
    fi
}

stop_services() {
    print_header "Stopping Services"
    
    cd "$PROJECT_ROOT"
    
    print_info "Stopping n8n services..."
    
    if docker compose ps 2>/dev/null | grep -q "postgres"; then
        docker compose -f compose.yaml -f compose.local-db.yaml down
    else
        docker compose down
    fi
    
    print_success "Services stopped"
}

restore_config_files() {
    print_header "Restoring Configuration Files"
    
    print_info "Restoring .env file..."
    
    if [[ -f "$RESTORE_DIR/.env" ]]; then
        # Backup current .env
        if [[ -f "$PROJECT_ROOT/.env" ]]; then
            cp "$PROJECT_ROOT/.env" "$PROJECT_ROOT/.env.backup-$(date +%Y%m%d-%H%M%S)"
        fi
        
        cp "$RESTORE_DIR/.env" "$PROJECT_ROOT/.env"
        chmod 600 "$PROJECT_ROOT/.env"
        print_success ".env file restored"
    else
        print_warning ".env file not found in backup"
    fi
    
    # Restore compose files if needed
    if [[ -f "$RESTORE_DIR/compose.yaml" ]]; then
        print_info "Compose files found in backup (not overwriting current)"
    fi
}

restore_database() {
    print_header "Restoring Database"
    
    if [[ ! -f "$RESTORE_DIR/database.dump" ]]; then
        print_error "Database dump not found in backup"
        exit 1
    fi
    
    cd "$PROJECT_ROOT"
    source .env
    
    # Check if using local or external database
    if grep -q "postgres" compose.yaml || [[ -z "${DATABASE_URL:-}" ]]; then
        # Local PostgreSQL - need to start it first
        print_info "Starting PostgreSQL service..."
        docker compose -f compose.yaml -f compose.local-db.yaml up -d postgres
        
        # Wait for PostgreSQL to be ready
        print_info "Waiting for PostgreSQL to be ready..."
        for i in {1..30}; do
            if docker compose exec -T postgres pg_isready &> /dev/null; then
                break
            fi
            sleep 2
        done
        
        print_info "Restoring database to local PostgreSQL..."
        
        # Drop and recreate database
        docker compose exec -T postgres psql -U "${POSTGRES_USER}" -d postgres <<EOF
DROP DATABASE IF EXISTS "${POSTGRES_DB}";
CREATE DATABASE "${POSTGRES_DB}" OWNER "${POSTGRES_USER}";
EOF
        
        # Restore database
        docker compose exec -T postgres pg_restore \
            -U "${POSTGRES_USER}" \
            -d "${POSTGRES_DB}" \
            --clean \
            --if-exists \
            < "$RESTORE_DIR/database.dump"
        
        print_success "Database restored to local PostgreSQL"
    else
        # External PostgreSQL
        print_info "Restoring database to external PostgreSQL..."
        
        if command -v pg_restore &> /dev/null; then
            pg_restore "$DATABASE_URL" \
                --clean \
                --if-exists \
                < "$RESTORE_DIR/database.dump"
            
            print_success "Database restored to external PostgreSQL"
        else
            print_error "pg_restore not found. Install postgresql-client."
            exit 1
        fi
    fi
}

start_services() {
    print_header "Starting Services"
    
    cd "$PROJECT_ROOT"
    
    print_info "Starting all services..."
    
    if docker compose ps 2>/dev/null | grep -q "postgres"; then
        docker compose -f compose.yaml -f compose.local-db.yaml up -d
    else
        docker compose up -d
    fi
    
    print_success "Services started"
}

wait_for_services() {
    print_header "Waiting for Services"
    
    print_info "Waiting for n8n to be ready..."
    
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker compose exec -T n8n-web wget -q --spider http://localhost:5678/healthz 2>/dev/null; then
            print_success "n8n is ready"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done
    
    echo ""
    print_warning "n8n did not become ready within expected time"
    print_info "Check logs with: docker compose logs n8n-web"
}

cleanup_restore_files() {
    print_header "Cleanup"
    
    print_info "Removing temporary restore files..."
    rm -rf "$RESTORE_DIR"
    
    print_success "Cleanup complete"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    clear
    
    print_banner "n8n Restore Tool" "By David Nagtzaam" "davidnagtzaam.com"
    
    # Check for backup file argument
    if [[ $# -eq 0 ]]; then
        print_error "Usage: sudo bash $0 <backup-file.tgz>"
        echo ""
        print_info "Available backups:"
        ls -lh /tmp/n8n-backup-*.tgz 2>/dev/null || print_warning "No local backups found"
        exit 1
    fi
    
    local backup_file="$1"
    
    # Validate backup
    validate_backup_file "$backup_file"
    
    # Extract backup
    extract_backup "$backup_file"
    
    # Confirm restore
    confirm_restore
    
    # Execute restore
    stop_services
    restore_config_files
    restore_database
    start_services
    wait_for_services
    cleanup_restore_files
    
    # Summary
    print_header "Restore Complete!"
    echo ""
    print_success "n8n has been restored from backup"
    echo ""
    print_info "Your instance should now be accessible"
    echo ""
    print_info "Useful commands:"
    echo "  • View logs:        docker compose logs -f n8n-web"
    echo "  • Check status:     docker compose ps"
    echo "  • Health check:     bash scripts/healthcheck.sh"
    echo ""
}

# Check if running as root for Docker access
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root or with sudo"
    exit 1
fi

main "$@"
