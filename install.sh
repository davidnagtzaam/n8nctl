#!/usr/bin/env bash
# ============================================================================
# n8nctl - Installation Script
# ============================================================================
# Created by: David Nagtzaam - https://davidnagtzaam.com
#
# Installs n8nctl to /opt/n8nctl following Linux FHS standards
# Makes n8nctl available system-wide via symlink in /usr/local/bin
# ============================================================================

set -euo pipefail

# Configuration
INSTALL_DIR="/opt/n8nctl"
BIN_LINK="/usr/local/bin/n8nctl"
VERSION_FILE="VERSION"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================================
# Helper Functions
# ============================================================================

print_banner() {
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}           n8nctl Installation${NC}"
    echo -e "${CYAN}${BOLD}    Professional n8n Deployment Tool${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# ============================================================================
# Check Functions
# ============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This installation requires root privileges"
        echo ""
        echo "Please run with sudo:"
        echo "  sudo bash install.sh"
        exit 1
    fi
}

check_source_location() {
    # Verify we're running from the n8nctl directory
    if [[ ! -f "scripts/n8nctl" ]] || [[ ! -f "compose.yaml" ]]; then
        print_error "Installation must be run from the n8nctl directory"
        echo ""
        echo "Please cd to the n8nctl directory first:"
        echo "  cd /path/to/n8nctl"
        echo "  sudo bash install.sh"
        exit 1
    fi
}

get_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        echo "1.0.0"
    fi
}

# ============================================================================
# Installation Functions
# ============================================================================

backup_existing() {
    if [[ -d "$INSTALL_DIR" ]]; then
        local backup_dir="${INSTALL_DIR}.backup-$(date +%Y%m%d-%H%M%S)"
        print_warning "Existing installation found"
        print_info "Creating backup at: $backup_dir"
        mv "$INSTALL_DIR" "$backup_dir"
        print_success "Backup created"
    fi
}

copy_files() {
    print_info "Copying files to $INSTALL_DIR..."

    # Create installation directory
    mkdir -p "$INSTALL_DIR"

    # Copy all files
    cp -r . "$INSTALL_DIR/"

    # Set proper ownership
    chown -R root:root "$INSTALL_DIR"

    # Set executable permissions for scripts
    chmod +x "$INSTALL_DIR/scripts/n8nctl"
    chmod +x "$INSTALL_DIR"/scripts/*.sh

    # Set secure permissions for lib files
    chmod 644 "$INSTALL_DIR"/lib/*.sh

    print_success "Files copied successfully"
}

create_symlink() {
    print_info "Creating system-wide command..."

    # Remove existing symlink if present
    if [[ -L "$BIN_LINK" ]]; then
        rm "$BIN_LINK"
    elif [[ -f "$BIN_LINK" ]]; then
        print_error "A file already exists at $BIN_LINK (not a symlink)"
        print_info "Please remove it manually and run install again"
        exit 1
    fi

    # Create symlink
    ln -s "$INSTALL_DIR/scripts/n8nctl" "$BIN_LINK"

    print_success "Command 'n8nctl' is now available system-wide"
}

install_man_pages() {
    if [[ -d "$INSTALL_DIR/man/man1" ]]; then
        print_info "Installing man pages..."

        mkdir -p /usr/local/share/man/man1
        cp "$INSTALL_DIR"/man/man1/*.1 /usr/local/share/man/man1/
        chmod 644 /usr/local/share/man/man1/n8nctl.1

        # Update man database
        if command -v mandb &> /dev/null; then
            mandb -q 2>/dev/null || true
        elif command -v makewhatis &> /dev/null; then
            makewhatis 2>/dev/null || true
        fi

        print_success "Man pages installed (access with: man n8nctl)"
    fi
}

create_data_directory() {
    print_info "Creating data directory..."

    # Create directory for runtime data (compose files will use this)
    mkdir -p "$INSTALL_DIR/data"
    chmod 755 "$INSTALL_DIR/data"

    print_success "Data directory created"
}

# ============================================================================
# Post-Install
# ============================================================================

show_next_steps() {
    local version=$(get_version)

    echo ""
    print_header "Installation Complete! 🎉"

    echo -e "${GREEN}${BOLD}n8nctl v${version} has been installed successfully${NC}"
    echo ""
    echo -e "${CYAN}Installation Details:${NC}"
    echo "  • Installation directory: $INSTALL_DIR"
    echo "  • Command location: $BIN_LINK"
    echo "  • Man page: man n8nctl"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo ""
    echo "  1. Check system requirements:"
    echo -e "     ${GREEN}sudo n8nctl preflight${NC}"
    echo ""
    echo "  2. Run interactive setup:"
    echo -e "     ${GREEN}sudo n8nctl init${NC}"
    echo ""
    echo "  3. View available commands:"
    echo -e "     ${GREEN}n8nctl help${NC}"
    echo ""
    echo -e "${CYAN}Quick Start:${NC}"
    echo "  • View status:    n8nctl status"
    echo "  • View logs:      n8nctl logs tail"
    echo "  • Create backup:  n8nctl backup"
    echo "  • Get help:       n8nctl help"
    echo ""
    echo -e "${CYAN}Documentation:${NC}"
    echo "  • Man page:       man n8nctl"
    echo "  • README:         cat $INSTALL_DIR/README.md"
    echo "  • Claude guide:   cat $INSTALL_DIR/CLAUDE.md"
    echo ""
    echo -e "${CYAN}Uninstall:${NC}"
    echo "  • Run:            sudo n8nctl uninstall"
    echo ""
    echo -e "${BLUE}Created by David Nagtzaam - https://davidnagtzaam.com${NC}"
    echo ""
}

# ============================================================================
# Main Installation
# ============================================================================

main() {
    print_banner

    print_info "Starting n8nctl installation..."
    echo ""

    # Pre-flight checks
    check_root
    check_source_location

    local version=$(get_version)
    print_info "Installing version: $version"
    echo ""

    # Confirm installation
    read -p "Install n8nctl to $INSTALL_DIR? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi

    echo ""
    print_header "Installing n8nctl"

    # Run installation steps
    backup_existing
    copy_files
    create_symlink
    install_man_pages
    create_data_directory

    # Show completion message
    show_next_steps
}

main "$@"
