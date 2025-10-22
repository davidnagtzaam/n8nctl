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
REPO_URL="https://github.com/davidnagtzaam/n8nctl.git"
INSTALL_DIR="/opt/n8nctl"

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
    print_header "Downloading n8nctl"

    # Create temporary directory
    local temp_dir=$(mktemp -d)

    print_info "Cloning repository..."
    git clone --depth=1 "$REPO_URL" "$temp_dir"

    print_success "Repository downloaded"

    echo "$temp_dir"
}

run_installation() {
    local temp_dir="$1"

    print_header "Installing n8nctl"

    cd "$temp_dir"

    # Run installation script
    print_info "Running installation..."
    bash install.sh

    # Clean up temp directory
    cd /
    rm -rf "$temp_dir"

    print_success "Installation complete"
}

run_setup() {
    print_header "n8n Setup"

    print_info "Running preflight checks..."
    n8nctl preflight

    echo ""
    read -p "Continue with n8n setup? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Starting interactive setup..."
        n8nctl init
    else
        print_info "Setup skipped. Run 'sudo n8nctl init' when ready."
    fi
}

main() {
    clear

    print_header "n8nctl Bootstrap Installer"
    echo ""
    print_info "Created by David Nagtzaam - https://davidnagtzaam.com"
    echo ""
    print_info "This will:"
    echo "  1. Download n8nctl from GitHub"
    echo "  2. Install to $INSTALL_DIR"
    echo "  3. Make 'n8nctl' available system-wide"
    echo "  4. Run preflight checks"
    echo "  5. Start interactive n8n setup"
    echo ""

    read -p "Continue with installation? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi

    echo ""
    check_root
    check_dependencies

    # Download and install
    local temp_dir=$(clone_repository)
    run_installation "$temp_dir"

    # Run setup
    run_setup

    print_header "Bootstrap Complete! 🎉"
    echo ""
    print_success "n8nctl is now installed and ready to use"
    echo ""
    print_info "Quick reference:"
    echo "  • View status:    n8nctl status"
    echo "  • View logs:      n8nctl logs tail"
    echo "  • Create backup:  n8nctl backup"
    echo "  • Get help:       n8nctl help"
    echo "  • Man page:       man n8nctl"
    echo ""
    print_info "Installation directory: $INSTALL_DIR"
    echo ""
}

main "$@"
