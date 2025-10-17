#!/usr/bin/env bash
# ============================================================================
# n8n Production Deployment - Preflight Check
# ============================================================================
# Created by: David Nagtzaam - https://davidnagtzaam.com
#
# This script verifies that the system meets all requirements before
# installation. It checks for:
# - Operating system compatibility
# - Docker and Docker Compose installation
# - Required ports availability
# - Sufficient disk space and memory
# - Network connectivity
# ============================================================================

set -euo pipefail

# Load shared UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/lib-ui.sh"

# Counters
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
# Checks
# ============================================================================

check_root() {
    print_header "Checking Permissions"
    if [[ $EUID -eq 0 ]]; then
        print_success "Running as root/sudo"
    else
        print_error "This script must be run as root or with sudo"
        print_info "Run: sudo bash $0"
    fi
}

check_os() {
    print_header "Checking Operating System"
    
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot detect operating system"
        return
    fi
    
    source /etc/os-release
    
    print_info "Detected: $PRETTY_NAME"
    
    case "$ID" in
        ubuntu|debian)
            if [[ "$VERSION_ID" =~ ^(20|22|24|11|12) ]]; then
                print_success "Supported OS detected"
            else
                print_warning "OS version may not be fully tested"
            fi
            ;;
        centos|rhel|fedora|rocky|almalinux)
            print_success "Supported OS detected"
            ;;
        *)
            print_warning "Untested OS. Should work if Docker is compatible."
            ;;
    esac
}

check_docker() {
    print_header "Checking Docker"
    
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        print_success "Docker installed: v$DOCKER_VERSION"
        
        # Check if Docker daemon is running
        if docker info &> /dev/null; then
            print_success "Docker daemon is running"
        else
            print_error "Docker daemon is not running. Start with: sudo systemctl start docker"
        fi
        
        # Check Docker Compose plugin
        if docker compose version &> /dev/null; then
            COMPOSE_VERSION=$(docker compose version --short)
            print_success "Docker Compose plugin installed: v$COMPOSE_VERSION"
        else
            print_error "Docker Compose plugin not found"
            print_info "Install with: sudo apt-get install docker-compose-plugin"
        fi
    else
        print_error "Docker not installed"
        print_info "Install Docker: https://docs.docker.com/engine/install/"
    fi
}

check_ports() {
    print_header "Checking Port Availability"
    
    REQUIRED_PORTS=(80 443)
    
    for PORT in "${REQUIRED_PORTS[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$PORT " || ss -tuln 2>/dev/null | grep -q ":$PORT "; then
            print_warning "Port $PORT is already in use"
            print_info "Check with: sudo netstat -tuln | grep :$PORT"
        else
            print_success "Port $PORT is available"
        fi
    done
}

check_disk_space() {
    print_header "Checking Disk Space"
    
    AVAILABLE_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    
    print_info "Available disk space: ${AVAILABLE_GB}GB"
    
    if [[ $AVAILABLE_GB -ge 20 ]]; then
        print_success "Sufficient disk space available"
    elif [[ $AVAILABLE_GB -ge 10 ]]; then
        print_warning "Low disk space. 20GB+ recommended for production"
    else
        print_error "Insufficient disk space. Minimum 10GB required, 20GB+ recommended"
    fi
}

check_memory() {
    print_header "Checking Memory"
    
    TOTAL_MEM_GB=$(free -g | awk '/^Mem:/ {print $2}')
    AVAILABLE_MEM_GB=$(free -g | awk '/^Mem:/ {print $7}')
    
    print_info "Total memory: ${TOTAL_MEM_GB}GB"
    print_info "Available memory: ${AVAILABLE_MEM_GB}GB"
    
    if [[ $TOTAL_MEM_GB -ge 4 ]]; then
        print_success "Sufficient memory available"
    elif [[ $TOTAL_MEM_GB -ge 2 ]]; then
        print_warning "Low memory. 4GB+ recommended for production"
    else
        print_error "Insufficient memory. Minimum 2GB required, 4GB+ recommended"
    fi
}

check_network() {
    print_header "Checking Network Connectivity"
    
    # Check DNS resolution
    if nslookup docker.io &> /dev/null || host docker.io &> /dev/null; then
        print_success "DNS resolution working"
    else
        print_warning "DNS resolution may be failing"
    fi
    
    # Check internet connectivity
    if curl -s --connect-timeout 5 https://docker.io &> /dev/null; then
        print_success "Internet connectivity working"
    else
        print_warning "Cannot reach docker.io. Check internet connection"
    fi
}

check_firewall() {
    print_header "Checking Firewall"
    
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            print_info "UFW firewall is active"
            if ufw status | grep -qE "80|443"; then
                print_success "Ports 80/443 allowed in UFW"
            else
                print_warning "Ports 80/443 may need to be allowed in UFW"
                print_info "Allow with: sudo ufw allow 80/tcp && sudo ufw allow 443/tcp"
            fi
        else
            print_info "UFW firewall is inactive"
        fi
    elif command -v firewall-cmd &> /dev/null; then
        print_info "Firewalld detected"
        if systemctl is-active --quiet firewalld; then
            print_info "Firewalld is active"
        else
            print_info "Firewalld is inactive"
        fi
    else
        print_info "No firewall detected (or not UFW/firewalld)"
    fi
}

check_dependencies() {
    print_header "Checking System Dependencies"
    
    DEPENDENCIES=(curl wget git openssl)
    
    for DEP in "${DEPENDENCIES[@]}"; do
        if command -v "$DEP" &> /dev/null; then
            print_success "$DEP is installed"
        else
            print_warning "$DEP is not installed (recommended)"
            print_info "Install with: sudo apt-get install $DEP"
        fi
    done
}

check_selinux() {
    print_header "Checking SELinux"
    
    if command -v getenforce &> /dev/null; then
        SELINUX_STATUS=$(getenforce)
        print_info "SELinux status: $SELINUX_STATUS"
        
        if [[ "$SELINUX_STATUS" == "Enforcing" ]]; then
            print_warning "SELinux is enforcing. May need additional configuration"
            print_info "Consider running: sudo setenforce 0 (temporary)"
        fi
    else
        print_info "SELinux not detected"
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    clear
    
    print_banner "n8n Preflight Check" "By David Nagtzaam" "davidnagtzaam.com"
    
    check_root
    check_os
    check_docker
    check_ports
    check_disk_space
    check_memory
    check_network
    check_firewall
    check_dependencies
    check_selinux
    
    # Summary
    echo ""
    print_header "Preflight Check Summary"
    echo ""
    
    if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
        print_success "All checks passed! Ready to proceed with installation."
        echo ""
        print_info "Next step: Run 'sudo bash scripts/init.sh'"
    elif [[ $ERRORS -eq 0 ]]; then
        print_warning "$WARNINGS warning(s) found. You can proceed but review the warnings above."
        echo ""
        print_info "Next step: Run 'sudo bash scripts/init.sh'"
    else
        print_error "$ERRORS error(s) and $WARNINGS warning(s) found."
        echo ""
        print_error "Please fix the errors above before proceeding."
        exit 1
    fi
    
    echo ""
}

main "$@"
