#!/usr/bin/env bash
# ============================================================================
# n8n Production Deployment - Bootstrap Script
# ============================================================================
# Created by: David Nagtzaam - https://davidnagtzaam.com
#
# One-line installer for n8n deployment
# Usage: curl -fsSL https://raw.githubusercontent.com/.../bootstrap.sh | sudo bash
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REPO_URL="https://github.com/davidnagtzaam/n8n-deploy.git"
INSTALL_DIR="/opt/n8n-deploy"

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
}

check_dependencies() {
    print_header "Checking Dependencies"
    
    local missing_deps=()
    
    for dep in git curl wget; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_info "Installing missing dependencies: ${missing_deps[*]}"
        
        if command -v apt-get &> /dev/null; then
            apt-get update -qq
            apt-get install -y "${missing_deps[@]}"
        elif command -v yum &> /dev/null; then
            yum install -y "${missing_deps[@]}"
        else
            print_error "Cannot install dependencies. Please install manually: ${missing_deps[*]}"
            exit 1
        fi
    fi
    
    print_success "Dependencies checked"
}

clone_repository() {
    print_header "Downloading n8n Deployment"
    
    # Remove existing installation if present
    if [[ -d "$INSTALL_DIR" ]]; then
        print_info "Existing installation found, backing up..."
        mv "$INSTALL_DIR" "${INSTALL_DIR}.backup-$(date +%Y%m%d-%H%M%S)"
    fi
    
    print_info "Cloning repository to $INSTALL_DIR..."
    git clone --depth=1 "$REPO_URL" "$INSTALL_DIR"
    
    cd "$INSTALL_DIR"
    chmod +x scripts/*.sh
    
    print_success "Repository cloned successfully"
}

run_installation() {
    print_header "Starting Installation"
    
    cd "$INSTALL_DIR"
    
    # Run preflight checks
    print_info "Running preflight checks..."
    bash scripts/preflight.sh
    
    # Run interactive setup
    print_info "Starting interactive setup..."
    bash scripts/init.sh
}

main() {
    clear
    
    print_header "n8n Production Deployment - Bootstrap Installer"
    echo ""
    print_info "Created by David Nagtzaam - https://davidnagtzaam.com"
    echo ""
    print_info "This will install n8n in: $INSTALL_DIR"
    echo ""
    
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi
    
    check_root
    check_dependencies
    clone_repository
    run_installation
    
    print_header "Bootstrap Complete!"
    echo ""
    print_success "n8n deployment has been installed to $INSTALL_DIR"
    echo ""
    print_info "Useful commands:"
    echo "  cd $INSTALL_DIR"
    echo "  make status"
    echo "  make logs"
    echo ""
}

main "$@"
