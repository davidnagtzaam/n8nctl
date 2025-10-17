#!/usr/bin/env bash
# =============================================================================
# n8n Production Deployment - Automated Testing Script
# =============================================================================
# Description: Validates deployment configuration and service health
# Author: David Nagtzaam
# Version: 1.0.0
# =============================================================================

set -euo pipefail

# Load shared UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/lib-ui.sh"

# Variables
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# =============================================================================
# Test Functions
# =============================================================================

# Test result tracking
record_pass() {
    local test_name="${1}"
    print_success "$test_name"
    ((TESTS_PASSED++))
}

record_fail() {
    local test_name="${1}"
    local reason="${2:-}"
    print_error "$test_name"
    if [ -n "$reason" ]; then
        echo "  ${SYMBOL_ARROW} Reason: $reason"
    fi
    ((TESTS_FAILED++))
}

record_skip() {
    local test_name="${1}"
    local reason="${2:-Not applicable}"
    print_info "$test_name [SKIPPED]"
    echo "  ${SYMBOL_ARROW} $reason"
    ((TESTS_SKIPPED++))
}

# -----------------------------------------------------------------------------
# Environment Tests
# -----------------------------------------------------------------------------

test_env_file_exists() {
    print_step "Checking .env file..."
    
    if [ -f "$PROJECT_ROOT/.env" ]; then
        record_pass ".env file exists"
        return 0
    else
        record_fail ".env file missing" "Run: sudo ./scripts/init.sh"
        return 1
    fi
}

test_env_file_permissions() {
    print_step "Checking .env permissions..."
    
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        record_skip ".env permissions" ".env file doesn't exist"
        return 0
    fi
    
    local perms=$(stat -c %a "$PROJECT_ROOT/.env" 2>/dev/null || stat -f %A "$PROJECT_ROOT/.env" 2>/dev/null)
    
    if [ "$perms" = "600" ]; then
        record_pass ".env permissions secure (600)"
        return 0
    else
        record_fail ".env permissions insecure ($perms)" "Run: chmod 600 .env"
        return 1
    fi
}

test_required_env_vars() {
    print_step "Checking required environment variables..."
    
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        record_skip "Required variables" ".env file doesn't exist"
        return 0
    fi
    
    source "$PROJECT_ROOT/.env" 2>/dev/null || true
    
    local required_vars=(
        "N8N_HOST"
        "N8N_PROTOCOL"
        "N8N_ENCRYPTION_KEY"
        "POSTGRES_PASSWORD"
    )
    
    local missing=()
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing+=("$var")
        fi
    done
    
    if [ ${#missing[@]} -eq 0 ]; then
        record_pass "All required variables present"
        return 0
    else
        record_fail "Missing variables: ${missing[*]}"
        return 1
    fi
}

test_placeholder_values() {
    print_step "Checking for placeholder values..."
    
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        record_skip "Placeholder values" ".env file doesn't exist"
        return 0
    fi
    
    local placeholders=$(grep -E "(change_me|your_|example\.com|placeholder)" "$PROJECT_ROOT/.env" | grep -v "^#" || true)
    
    if [ -z "$placeholders" ]; then
        record_pass "No placeholder values found"
        return 0
    else
        record_fail "Placeholder values detected" "Update .env with real values"
        echo "$placeholders" | while read line; do
            echo "    ${SYMBOL_ARROW} $line"
        done
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Docker Tests
# -----------------------------------------------------------------------------

test_docker_installed() {
    print_step "Checking Docker installation..."
    
    if command -v docker &> /dev/null; then
        local version=$(docker --version | cut -d' ' -f3 | tr -d ',')
        record_pass "Docker installed (v$version)"
        return 0
    else
        record_fail "Docker not installed" "Install from: https://docs.docker.com/get-docker/"
        return 1
    fi
}

test_docker_compose_installed() {
    print_step "Checking Docker Compose..."
    
    if docker compose version &> /dev/null; then
        local version=$(docker compose version --short)
        record_pass "Docker Compose installed (v$version)"
        return 0
    else
        record_fail "Docker Compose not available"
        return 1
    fi
}

test_docker_running() {
    print_step "Checking Docker daemon..."
    
    if docker info &> /dev/null; then
        record_pass "Docker daemon is running"
        return 0
    else
        record_fail "Docker daemon not running" "Start Docker service"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Service Tests
# -----------------------------------------------------------------------------

test_services_running() {
    print_step "Checking service status..."
    
    cd "$PROJECT_ROOT"
    
    local running=$(docker compose ps --format json 2>/dev/null | jq -r '.State' 2>/dev/null | grep -c "running" || echo "0")
    local total=$(docker compose ps -a --format json 2>/dev/null | jq -r '.State' 2>/dev/null | wc -l || echo "0")
    
    if [ "$total" -eq 0 ]; then
        record_skip "Service status" "No services deployed yet"
        return 0
    fi
    
    if [ "$running" -eq "$total" ]; then
        record_pass "All services running ($running/$total)"
        return 0
    else
        record_fail "Some services not running ($running/$total)"
        echo "  ${SYMBOL_ARROW} Check logs: docker compose logs"
        return 1
    fi
}

test_service_health() {
    print_step "Checking service health..."
    
    cd "$PROJECT_ROOT"
    
    if ! docker compose ps --format json &> /dev/null; then
        record_skip "Service health" "No services running"
        return 0
    fi
    
    local unhealthy=$(docker compose ps --format json 2>/dev/null | jq -r 'select(.Health=="unhealthy") | .Name' 2>/dev/null || true)
    
    if [ -z "$unhealthy" ]; then
        record_pass "All services healthy"
        return 0
    else
        record_fail "Unhealthy services detected"
        echo "$unhealthy" | while read service; do
            echo "  ${SYMBOL_ARROW} $service"
        done
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Database Tests
# -----------------------------------------------------------------------------

test_database_connectivity() {
    print_step "Testing database connectivity..."
    
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        record_skip "Database connectivity" ".env file doesn't exist"
        return 0
    fi
    
    source "$PROJECT_ROOT/.env"
    cd "$PROJECT_ROOT"
    
    # Check if using local or external database
    if docker compose ps --format json 2>/dev/null | jq -r .Name | grep -q "postgres" 2>/dev/null; then
        # Local PostgreSQL
        if docker compose exec -T postgres pg_isready -U "${POSTGRES_USER}" &> /dev/null; then
            record_pass "Local PostgreSQL responding"
            return 0
        else
            record_fail "Local PostgreSQL not responding"
            return 1
        fi
    elif [ -n "${DATABASE_URL:-}" ]; then
        # External PostgreSQL - just check if variable is set
        record_pass "External PostgreSQL configured"
        return 0
    else
        record_skip "Database connectivity" "Database not configured"
        return 0
    fi
}

# -----------------------------------------------------------------------------
# Redis Tests
# -----------------------------------------------------------------------------

test_redis_connectivity() {
    print_step "Testing Redis connectivity..."
    
    cd "$PROJECT_ROOT"
    
    if ! docker compose ps --format json 2>/dev/null | jq -r .Name | grep -q "redis" 2>/dev/null; then
        record_skip "Redis connectivity" "Redis not running"
        return 0
    fi
    
    if docker compose exec -T redis redis-cli ping &> /dev/null; then
        record_pass "Redis responding"
        return 0
    else
        record_fail "Redis not responding"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# n8n Tests
# -----------------------------------------------------------------------------

test_n8n_api() {
    print_step "Testing n8n API..."
    
    cd "$PROJECT_ROOT"
    
    if ! docker compose ps --format json 2>/dev/null | jq -r .Name | grep -q "n8n-web" 2>/dev/null; then
        record_skip "n8n API" "n8n not running"
        return 0
    fi
    
    if docker compose exec -T n8n-web wget -q --spider http://localhost:5678/healthz 2>/dev/null; then
        record_pass "n8n API responding"
        return 0
    else
        record_fail "n8n API not responding"
        return 1
    fi
}

test_n8n_workers() {
    print_step "Testing n8n workers..."
    
    cd "$PROJECT_ROOT"
    
    local worker_count=$(docker compose ps --format json 2>/dev/null | jq -r .Name 2>/dev/null | grep -c "n8n-worker" || echo "0")
    
    if [ "$worker_count" -eq 0 ]; then
        record_skip "n8n workers" "No workers configured"
        return 0
    fi
    
    local healthy_workers=$(docker compose ps --format json 2>/dev/null | jq -r 'select(.Name | contains("n8n-worker")) | select(.Health != "unhealthy") | .Name' 2>/dev/null | wc -l)
    
    if [ "$healthy_workers" -eq "$worker_count" ]; then
        record_pass "All workers healthy ($healthy_workers/$worker_count)"
        return 0
    else
        record_fail "Some workers unhealthy ($healthy_workers/$worker_count)"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Network Tests
# -----------------------------------------------------------------------------

test_traefik_routing() {
    print_step "Testing Traefik routing..."
    
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        record_skip "Traefik routing" ".env file doesn't exist"
        return 0
    fi
    
    source "$PROJECT_ROOT/.env"
    cd "$PROJECT_ROOT"
    
    if ! docker compose ps --format json 2>/dev/null | jq -r .Name | grep -q "traefik" 2>/dev/null; then
        record_skip "Traefik routing" "Traefik not running"
        return 0
    fi
    
    # Check if traefik is healthy
    if docker compose exec -T traefik traefik healthcheck --ping &> /dev/null; then
        record_pass "Traefik responding"
        return 0
    else
        record_fail "Traefik not responding"
        return 1
    fi
}

test_ssl_certificate() {
    print_step "Testing SSL certificate..."
    
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        record_skip "SSL certificate" ".env file doesn't exist"
        return 0
    fi
    
    source "$PROJECT_ROOT/.env"
    
    # Check if certificate exists
    local cert_path="$PROJECT_ROOT/traefik/acme.json"
    if [ -f "$cert_path" ] || docker volume inspect n8n-traefik-acme &> /dev/null; then
        record_pass "SSL certificate configured"
        return 0
    else
        record_skip "SSL certificate" "Will be generated on first HTTPS request"
        return 0
    fi
}

# -----------------------------------------------------------------------------
# Storage Tests
# -----------------------------------------------------------------------------

test_storage_configuration() {
    print_step "Testing storage configuration..."
    
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        record_skip "Storage configuration" ".env file doesn't exist"
        return 0
    fi
    
    source "$PROJECT_ROOT/.env"
    
    local mode="${N8N_DEFAULT_BINARY_DATA_MODE:-default}"
    
    if [ "$mode" = "default" ]; then
        # Local storage - check volume
        if docker volume inspect n8n-data &> /dev/null; then
            record_pass "Local storage configured"
            return 0
        else
            record_skip "Local storage" "Volume will be created on first start"
            return 0
        fi
    elif [ "$mode" = "s3" ]; then
        # S3 storage - check variables
        if [ -n "${S3_BUCKET:-}" ] && [ -n "${S3_ACCESS_KEY_ID:-}" ]; then
            record_pass "S3 storage configured"
            return 0
        else
            record_fail "S3 storage incomplete" "Check S3_* variables in .env"
            return 1
        fi
    else
        record_fail "Unknown storage mode: $mode"
        return 1
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

run_all_tests() {
    print_banner "n8n Deployment Test Suite" "Version 1.0.0"
    
    echo ""
    print_header "Environment Tests"
    test_env_file_exists
    test_env_file_permissions
    test_required_env_vars
    test_placeholder_values
    
    echo ""
    print_header "Docker Tests"
    test_docker_installed
    test_docker_compose_installed
    test_docker_running
    
    echo ""
    print_header "Service Tests"
    test_services_running
    test_service_health
    
    echo ""
    print_header "Database Tests"
    test_database_connectivity
    
    echo ""
    print_header "Redis Tests"
    test_redis_connectivity
    
    echo ""
    print_header "n8n Tests"
    test_n8n_api
    test_n8n_workers
    
    echo ""
    print_header "Network Tests"
    test_traefik_routing
    test_ssl_certificate
    
    echo ""
    print_header "Storage Tests"
    test_storage_configuration
}

show_summary() {
    echo ""
    print_header "Test Summary"
    
    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
    
    echo ""
    echo "  ${SYMBOL_SUCCESS} Passed:  $TESTS_PASSED"
    echo "  ${SYMBOL_ERROR} Failed:  $TESTS_FAILED"
    echo "  ${SYMBOL_INFO} Skipped: $TESTS_SKIPPED"
    echo "  ${SYMBOL_ARROW} Total:   $total"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        print_success "All tests passed! Deployment is ready."
        return 0
    else
        print_error "Some tests failed. Please address the issues above."
        return 1
    fi
}

main() {
    run_all_tests
    show_summary
}

main "$@"
