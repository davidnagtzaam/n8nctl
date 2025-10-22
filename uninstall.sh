#!/usr/bin/env bash
# ============================================================================
# n8nctl - Uninstallation Script
# ============================================================================
# Created by: David Nagtzaam - https://davidnagtzaam.com
#
# Cleanly removes n8nctl from the system
# Preserves user data and configuration unless explicitly requested
# ============================================================================

set -euo pipefail

# Configuration
INSTALL_DIR="/opt/n8nctl"
BIN_LINK="/usr/local/bin/n8nctl"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/n8nctl"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Flags
REMOVE_DATA=false
REMOVE_CONFIG=false
FORCE=false

# ============================================================================
# Helper Functions
# ============================================================================

print_banner() {
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}           n8nctl Uninstallation${NC}"
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

show_usage() {
    cat <<EOF
Usage: sudo bash uninstall.sh [OPTIONS]

Options:
  --remove-data     Remove Docker volumes and n8n data
  --remove-config   Remove user configuration files
  --force           Skip confirmation prompts
  --help            Show this help message

Examples:
  sudo bash uninstall.sh                    # Remove n8nctl only
  sudo bash uninstall.sh --remove-data      # Remove n8nctl and all data
  sudo bash uninstall.sh --force            # Remove without confirmation

Note: By default, user data and configuration are preserved.
EOF
}

# ============================================================================
# Check Functions
# ============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Uninstallation requires root privileges"
        echo ""
        echo "Please run with sudo:"
        echo "  sudo bash uninstall.sh"
        exit 1
    fi
}

check_installation() {
    if [[ ! -d "$INSTALL_DIR" ]] && [[ ! -L "$BIN_LINK" ]]; then
        print_warning "n8nctl does not appear to be installed"
        exit 0
    fi
}

check_services_running() {
    if [[ -d "$INSTALL_DIR" ]]; then
        cd "$INSTALL_DIR" 2>/dev/null || return 0

        if docker compose ps 2>/dev/null | grep -q "Up"; then
            print_warning "n8n services are currently running"
            echo ""
            echo "Stop services before uninstalling:"
            echo "  n8nctl stop"
            echo ""
            read -p "Stop services now? (y/N): " -n 1 -r
            echo

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                docker compose down
                print_success "Services stopped"
            else
                print_error "Cannot uninstall while services are running"
                exit 1
            fi
        fi
    fi
}

# ============================================================================
# Uninstall Functions
# ============================================================================

remove_symlink() {
    if [[ -L "$BIN_LINK" ]]; then
        print_info "Removing command symlink..."
        rm "$BIN_LINK"
        print_success "Command removed"
    fi
}

remove_installation() {
    if [[ -d "$INSTALL_DIR" ]]; then
        print_info "Removing installation directory..."
        rm -rf "$INSTALL_DIR"
        print_success "Installation directory removed"
    fi
}

remove_man_pages() {
    if [[ -f "/usr/local/share/man/man1/n8nctl.1" ]]; then
        print_info "Removing man pages..."
        rm -f /usr/local/share/man/man1/n8nctl.1

        # Update man database
        if command -v mandb &> /dev/null; then
            mandb -q 2>/dev/null || true
        elif command -v makewhatis &> /dev/null; then
            makewhatis 2>/dev/null || true
        fi

        print_success "Man pages removed"
    fi
}

remove_docker_data() {
    if [[ "$REMOVE_DATA" == true ]]; then
        print_warning "Removing Docker volumes and n8n data..."
        echo ""
        print_warning "This will permanently delete:"
        echo "  • n8n workflows and credentials"
        echo "  • PostgreSQL database"
        echo "  • Redis data"
        echo "  • Traefik certificates"
        echo ""

        if [[ "$FORCE" != true ]]; then
            read -p "Are you SURE you want to delete all data? (yes/N): " -r
            echo

            if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                print_info "Data removal cancelled"
                return 0
            fi
        fi

        # Remove volumes
        docker volume rm n8n-data 2>/dev/null || true
        docker volume rm n8n-postgres-data 2>/dev/null || true
        docker volume rm n8n-redis-data 2>/dev/null || true
        docker volume rm n8n-traefik-acme 2>/dev/null || true
        docker volume rm n8n-traefik-logs 2>/dev/null || true

        print_success "Docker volumes removed"
    else
        print_info "Docker volumes preserved (use --remove-data to delete)"
    fi
}

remove_config() {
    if [[ "$REMOVE_CONFIG" == true ]]; then
        if [[ -d "$CONFIG_DIR" ]]; then
            print_info "Removing user configuration..."
            rm -rf "$CONFIG_DIR"
            print_success "Configuration removed"
        fi
    else
        print_info "User configuration preserved at: $CONFIG_DIR"
    fi
}

# ============================================================================
# Main Uninstallation
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --remove-data)
                REMOVE_DATA=true
                shift
                ;;
            --remove-config)
                REMOVE_CONFIG=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo ""
                show_usage
                exit 1
                ;;
        esac
    done
}

confirm_uninstall() {
    if [[ "$FORCE" == true ]]; then
        return 0
    fi

    echo ""
    print_warning "This will remove n8nctl from your system"
    echo ""
    echo "The following will be removed:"
    echo "  • Installation directory: $INSTALL_DIR"
    echo "  • Command: $BIN_LINK"
    echo "  • Man pages"
    echo ""

    if [[ "$REMOVE_DATA" == true ]]; then
        echo "  • Docker volumes (all n8n data) ⚠️"
    else
        echo "  • Docker volumes: Preserved"
    fi

    if [[ "$REMOVE_CONFIG" == true ]]; then
        echo "  • User configuration ⚠️"
    else
        echo "  • User configuration: Preserved"
    fi

    echo ""
    read -p "Continue with uninstallation? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
}

show_completion() {
    echo ""
    print_header "Uninstallation Complete"

    print_success "n8nctl has been removed from your system"
    echo ""

    if [[ "$REMOVE_DATA" != true ]]; then
        print_info "Docker volumes have been preserved"
        echo "  To remove them later, run:"
        echo "  docker volume rm n8n-data n8n-postgres-data n8n-redis-data n8n-traefik-acme n8n-traefik-logs"
        echo ""
    fi

    if [[ "$REMOVE_CONFIG" != true ]] && [[ -d "$CONFIG_DIR" ]]; then
        print_info "User configuration preserved at: $CONFIG_DIR"
        echo "  To remove it, run: rm -rf $CONFIG_DIR"
        echo ""
    fi

    print_info "To reinstall n8nctl, run: sudo bash install.sh"
    echo ""
}

main() {
    parse_args "$@"

    print_banner

    # Pre-flight checks
    check_root
    check_installation

    # Confirm and proceed
    confirm_uninstall

    echo ""
    print_header "Removing n8nctl"

    # Check and stop services if needed
    check_services_running

    # Remove components
    remove_symlink
    remove_man_pages
    remove_docker_data
    remove_installation
    remove_config

    # Show completion
    show_completion
}

main "$@"
