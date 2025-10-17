#!/usr/bin/env bash
# ============================================================================
# n8n Production Deployment - Health Check Script
# ============================================================================
# Created by: David Nagtzaam - https://davidnagtzaam.com
#
# This script performs comprehensive health checks on all services
# ============================================================================

set -euo pipefail

# Load shared UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/lib-ui.sh"

# Variables
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ERRORS=0
WARNINGS=0

# Override error and warning functions to track counts
_original_print_error=$(declare -f print_error)
_original_print_warning=$(declare -f print_warning)

print_error() {
    eval "${_original_print_error/print_error/}"
    ((ERRORS++))
}

print_warning() {
    eval "${_original_print_warning/print_warning/}"
    ((WARNINGS++))
}

# ============================================================================
# Health Check Functions
# ============================================================================

check_docker() {
    print_header "Docker Status"
    
    if docker info &> /dev/null; then
        print_success "Docker daemon is running"
    else
        print_error "Docker daemon is not running"
    fi
}

check_services_running() {
    print_header "Service Status"
    
    cd "$PROJECT_ROOT"
    
    local services=("traefik" "redis" "n8n-web" "n8n-worker")
    
    # Add postgres if using local DB
    if docker compose ps 2>/dev/null | grep -q "postgres"; then
        services+=("postgres")
    fi
    
    for service in "${services[@]}"; do
        if docker compose ps | grep "$service" | grep -q "Up"; then
            local uptime=$(docker compose ps | grep "$service" | awk '{print $(NF-1), $NF}')
            print_success "$service is running ($uptime)"
        else
            print_error "$service is not running"
        fi
    done
}

check_service_health() {
    print_header "Service Health Checks"
    
    cd "$PROJECT_ROOT"
    
    # Check Redis
    print_info "Checking Redis..."
    if docker compose exec -T redis redis-cli PING 2>&1 | grep -q "PONG"; then
        print_success "Redis is healthy"
    else
        print_error "Redis health check failed"
    fi
    
    # Check PostgreSQL (if local)
    if docker compose ps 2>/dev/null | grep -q "postgres"; then
        print_info "Checking PostgreSQL..."
        if docker compose exec -T postgres pg_isready 2>&1 | grep -q "accepting connections"; then
            print_success "PostgreSQL is healthy"
            
            # Check database connection
            if docker compose exec -T postgres psql -U n8n -d n8n -c "SELECT 1" &> /dev/null; then
                print_success "Database connection successful"
            else
                print_warning "Database connection failed"
            fi
        else
            print_error "PostgreSQL health check failed"
        fi
    fi
    
    # Check n8n web
    print_info "Checking n8n web service..."
    if docker compose exec -T n8n-web wget -q --spider http://localhost:5678/healthz 2>/dev/null; then
        print_success "n8n web service is responding"
    else
        print_warning "n8n web service health check failed"
    fi
    
    # Check Traefik
    print_info "Checking Traefik..."
    if docker compose exec -T traefik traefik healthcheck --ping &> /dev/null; then
        print_success "Traefik is healthy"
    else
        print_warning "Traefik health check failed"
    fi
}

check_endpoints() {
    print_header "External Endpoint Checks"
    
    cd "$PROJECT_ROOT"
    
    if [[ ! -f .env ]]; then
        print_warning ".env file not found, skipping endpoint checks"
        return
    fi
    
    source .env
    
    # Check HTTPS endpoint
    if [[ -n "${N8N_HOST:-}" ]]; then
        print_info "Checking https://${N8N_HOST}..."
        
        if curl -sSf -k "https://${N8N_HOST}/healthz" &> /dev/null; then
            print_success "HTTPS endpoint is accessible"
        else
            print_warning "HTTPS endpoint is not accessible (may still be initializing)"
        fi
    fi
}

check_volumes() {
    print_header "Docker Volumes"
    
    local volumes=("n8n-redis-data" "n8n-traefik-acme" "n8n-traefik-logs")
    
    # Add postgres volume if using local DB
    if docker compose ps 2>/dev/null | grep -q "postgres"; then
        volumes+=("n8n-postgres-data")
    fi
    
    for volume in "${volumes[@]}"; do
        if docker volume inspect "$volume" &> /dev/null; then
            local size=$(docker system df -v | grep "$volume" | awk '{print $3}')
            print_success "$volume exists${size:+ ($size)}"
        else
            print_warning "$volume does not exist"
        fi
    done
}

check_disk_space() {
    print_header "Disk Space"
    
    local available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    local used_percent=$(df / | awk 'NR==2 {print $5}')
    
    print_info "Available: ${available_gb}GB | Used: ${used_percent}"
    
    if [[ $available_gb -ge 10 ]]; then
        print_success "Sufficient disk space"
    elif [[ $available_gb -ge 5 ]]; then
        print_warning "Low disk space (less than 10GB)"
    else
        print_error "Critical: Very low disk space (less than 5GB)"
    fi
}

check_memory() {
    print_header "Memory Usage"
    
    local total_mem=$(free -h | awk '/^Mem:/ {print $2}')
    local used_mem=$(free -h | awk '/^Mem:/ {print $3}')
    local available_mem=$(free -h | awk '/^Mem:/ {print $7}')
    
    print_info "Total: $total_mem | Used: $used_mem | Available: $available_mem"
    
    local available_mb=$(free -m | awk '/^Mem:/ {print $7}')
    
    if [[ $available_mb -ge 1024 ]]; then
        print_success "Sufficient memory available"
    elif [[ $available_mb -ge 512 ]]; then
        print_warning "Low memory (less than 1GB available)"
    else
        print_error "Critical: Very low memory (less than 512MB available)"
    fi
}

check_container_logs() {
    print_header "Recent Container Errors"
    
    cd "$PROJECT_ROOT"
    
    # Check for recent errors in logs
    local services=("n8n-web" "n8n-worker" "redis" "traefik")
    
    for service in "${services[@]}"; do
        local error_count=$(docker compose logs --tail=100 "$service" 2>/dev/null | grep -i "error" | wc -l)
        
        if [[ $error_count -eq 0 ]]; then
            print_success "$service: No recent errors"
        elif [[ $error_count -le 5 ]]; then
            print_warning "$service: $error_count error(s) in recent logs"
        else
            print_error "$service: $error_count error(s) in recent logs - review logs!"
        fi
    done
}

check_queue_depth() {
    print_header "Queue Status"
    
    cd "$PROJECT_ROOT"
    
    # Check Redis queue depth
    local queue_depth=$(docker compose exec -T redis redis-cli LLEN "bull:n8n:jobs" 2>/dev/null || echo "N/A")
    
    if [[ "$queue_depth" == "N/A" ]]; then
        print_warning "Could not check queue depth"
    elif [[ "$queue_depth" =~ ^[0-9]+$ ]]; then
        if [[ $queue_depth -eq 0 ]]; then
            print_success "Queue is empty"
        elif [[ $queue_depth -le 100 ]]; then
            print_success "Queue depth: $queue_depth job(s)"
        elif [[ $queue_depth -le 1000 ]]; then
            print_warning "Queue depth: $queue_depth job(s) - consider scaling workers"
        else
            print_error "Queue depth: $queue_depth job(s) - critical, scale workers immediately!"
        fi
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    clear
    
    print_banner "🏥 n8n Health Check" "By David Nagtzaam" "davidnagtzaam.com"
    
    check_docker
    check_services_running
    check_service_health
    check_endpoints
    check_volumes
    check_disk_space
    check_memory
    check_container_logs
    check_queue_depth
    
    # Summary
    print_header "Health Check Summary"
    echo ""
    
    if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
        print_success "All health checks passed! System is healthy. 💚"
    elif [[ $ERRORS -eq 0 ]]; then
        print_warning "$WARNINGS warning(s) found. System is functional but review warnings."
    else
        print_error "$ERRORS error(s) and $WARNINGS warning(s) found."
        print_error "System may not be functioning correctly. Review errors above."
        exit 1
    fi
    
    echo ""
}

main "$@"
