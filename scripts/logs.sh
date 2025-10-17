#!/usr/bin/env bash
# =============================================================================
# n8n Production Deployment - Log Management Script
# =============================================================================
# Description: Centralized log viewing, searching, and exporting
# Author: David Nagtzaam
# Version: 1.0.0
# =============================================================================

set -euo pipefail

# Load shared UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/lib-ui.sh"

# Variables
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# =============================================================================
# Helper Functions
# =============================================================================

show_usage() {
    cat << EOF
n8n Log Management Tool

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  tail [SERVICE]     - Follow logs in real-time (default: all services)
  show [SERVICE]     - Show recent logs (default: last 100 lines)
  search PATTERN     - Search logs for pattern
  export [SERVICE]   - Export logs to file
  errors [SERVICE]   - Show only error messages
  list               - List all available services

Services:
  all                - All services (default)
  n8n-web            - Main n8n web interface
  n8n-worker         - Background workers
  postgres           - PostgreSQL database
  redis              - Redis cache/queue
  traefik            - Reverse proxy

Options:
  -n, --lines N      - Number of lines to show (default: 100)
  -f, --follow       - Follow log output
  -s, --since TIME   - Show logs since timestamp (e.g., '1h', '30m', '2024-01-01')
  
Examples:
  $0 tail            - Follow all logs
  $0 tail n8n-web    - Follow n8n-web logs only
  $0 show -n 500     - Show last 500 lines from all services
  $0 search "error"  - Search for errors in all logs
  $0 errors n8n-web  - Show only errors from n8n-web
  $0 export          - Export all logs to file

EOF
}

list_services() {
    print_header "Available Services"
    
    cd "$PROJECT_ROOT"
    
    local services=$(docker compose ps --format json 2>/dev/null | jq -r '.Name' 2>/dev/null || echo "")
    
    if [ -z "$services" ]; then
        print_warn "No services running"
        echo ""
        print_info "Start services with: docker compose up -d"
        return 1
    fi
    
    echo ""
    echo "$services" | while read service; do
        local status=$(docker compose ps --format json 2>/dev/null | jq -r "select(.Name==\"$service\") | .State" 2>/dev/null)
        local health=$(docker compose ps --format json 2>/dev/null | jq -r "select(.Name==\"$service\") | .Health" 2>/dev/null)
        
        if [ "$status" = "running" ]; then
            if [ "$health" = "healthy" ] || [ -z "$health" ]; then
                echo "  ${SYMBOL_SUCCESS} $service (running)"
            else
                echo "  ${SYMBOL_WARN} $service (running, $health)"
            fi
        else
            echo "  ${SYMBOL_ERROR} $service ($status)"
        fi
    done
    echo ""
}

validate_service() {
    local service="$1"
    
    if [ "$service" = "all" ] || [ -z "$service" ]; then
        return 0
    fi
    
    cd "$PROJECT_ROOT"
    
    if docker compose ps --format json 2>/dev/null | jq -r .Name | grep -q "^$service$"; then
        return 0
    else
        print_error "Service not found: $service"
        echo ""
        list_services
        return 1
    fi
}

# =============================================================================
# Log Commands
# =============================================================================

tail_logs() {
    local service="${1:-}"
    local lines="${2:-100}"
    
    print_header "Following Logs"
    
    if [ -n "$service" ] && [ "$service" != "all" ]; then
        print_info "Service: $service"
        echo ""
        cd "$PROJECT_ROOT"
        docker compose logs -f --tail="$lines" "$service"
    else
        print_info "Service: all services"
        echo ""
        cd "$PROJECT_ROOT"
        docker compose logs -f --tail="$lines"
    fi
}

show_logs() {
    local service="${1:-}"
    local lines="${2:-100}"
    local since="${3:-}"
    
    print_header "Recent Logs"
    
    cd "$PROJECT_ROOT"
    
    local cmd="docker compose logs --tail=$lines"
    
    if [ -n "$since" ]; then
        cmd="$cmd --since=$since"
        print_info "Showing logs since: $since"
    else
        print_info "Showing last $lines lines"
    fi
    
    if [ -n "$service" ] && [ "$service" != "all" ]; then
        print_info "Service: $service"
        cmd="$cmd $service"
    else
        print_info "Service: all services"
    fi
    
    echo ""
    eval "$cmd"
}

search_logs() {
    local pattern="$1"
    local service="${2:-}"
    
    print_header "Searching Logs"
    
    print_info "Pattern: $pattern"
    
    if [ -n "$service" ] && [ "$service" != "all" ]; then
        print_info "Service: $service"
    else
        print_info "Service: all services"
    fi
    
    echo ""
    
    cd "$PROJECT_ROOT"
    
    if [ -n "$service" ] && [ "$service" != "all" ]; then
        docker compose logs --no-log-prefix "$service" 2>/dev/null | grep -i --color=always "$pattern" || {
            print_warn "No matches found for: $pattern"
            return 1
        }
    else
        docker compose logs --no-log-prefix 2>/dev/null | grep -i --color=always "$pattern" || {
            print_warn "No matches found for: $pattern"
            return 1
        }
    fi
}

show_errors() {
    local service="${1:-}"
    
    print_header "Error Messages"
    
    if [ -n "$service" ] && [ "$service" != "all" ]; then
        print_info "Service: $service"
    else
        print_info "Service: all services"
    fi
    
    echo ""
    
    cd "$PROJECT_ROOT"
    
    if [ -n "$service" ] && [ "$service" != "all" ]; then
        docker compose logs --no-log-prefix "$service" 2>/dev/null | grep -iE "error|fail|exception|fatal" --color=always || {
            print_success "No errors found"
            return 0
        }
    else
        docker compose logs --no-log-prefix 2>/dev/null | grep -iE "error|fail|exception|fatal" --color=always || {
            print_success "No errors found"
            return 0
        }
    fi
}

export_logs() {
    local service="${1:-}"
    local timestamp=$(date +"%Y%m%d-%H%M%S")
    local filename
    
    if [ -n "$service" ] && [ "$service" != "all" ]; then
        filename="/tmp/n8n-logs-${service}-${timestamp}.log"
    else
        filename="/tmp/n8n-logs-all-${timestamp}.log"
    fi
    
    print_header "Exporting Logs"
    
    if [ -n "$service" ] && [ "$service" != "all" ]; then
        print_info "Service: $service"
    else
        print_info "Service: all services"
    fi
    
    print_info "Exporting to: $filename"
    
    cd "$PROJECT_ROOT"
    
    if [ -n "$service" ] && [ "$service" != "all" ]; then
        docker compose logs --no-log-prefix "$service" > "$filename" 2>&1
    else
        docker compose logs --no-log-prefix > "$filename" 2>&1
    fi
    
    local size=$(du -h "$filename" | cut -f1)
    
    echo ""
    print_success "Logs exported successfully"
    echo ""
    print_info "File: $filename"
    print_info "Size: $size"
    echo ""
    print_info "View with: less $filename"
    print_info "Search with: grep 'pattern' $filename"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    local command="${1:-}"
    shift || true
    
    # Parse options
    local service=""
    local lines=100
    local follow=false
    local since=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--lines)
                lines="$2"
                shift 2
                ;;
            -f|--follow)
                follow=true
                shift
                ;;
            -s|--since)
                since="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                if [ -z "$service" ]; then
                    service="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Validate service if specified
    if [ -n "$service" ] && [ "$service" != "all" ]; then
        if ! validate_service "$service"; then
            exit 1
        fi
    fi
    
    # Execute command
    case "$command" in
        tail)
            tail_logs "$service" "$lines"
            ;;
        show)
            show_logs "$service" "$lines" "$since"
            ;;
        search)
            if [ -z "$service" ]; then
                print_error "Search pattern required"
                echo ""
                show_usage
                exit 1
            fi
            local pattern="$service"
            service="${2:-}"
            search_logs "$pattern" "$service"
            ;;
        errors)
            show_errors "$service"
            ;;
        export)
            export_logs "$service"
            ;;
        list)
            list_services
            ;;
        -h|--help|help)
            show_usage
            exit 0
            ;;
        "")
            # Default: tail all logs
            tail_logs "" "$lines"
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
