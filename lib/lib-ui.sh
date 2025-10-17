#!/usr/bin/env bash
# ============================================================================
# n8n Production Deployment - Shared UI Library
# ============================================================================
# Created by: David Nagtzaam - https://davidnagtzaam.com
#
# This library provides beautiful terminal UI with gum (Charm.sh) integration
# and automatic fallbacks for environments without gum or TTY.
#
# Usage in scripts:
#   source "$(dirname "$0")/lib-ui.sh"
#
# Install gum: https://github.com/charmbracelet/gum
#   brew install gum          # macOS
#   apt install gum           # Ubuntu/Debian (from Charm repo)
#   go install github.com/charmbracelet/gum@latest
# ============================================================================

# ============================================================================
# Environment Detection
# ============================================================================

# Colors for fallback mode
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;35m'
export BOLD='\033[1m'
export DIM='\033[2m'
export NC='\033[0m'

# Professional symbols (Unicode, not emojis)
export SYMBOL_SUCCESS="✓"  # Checkmark
export SYMBOL_ERROR="✗"    # X mark
export SYMBOL_PENDING="○"  # Open circle
export SYMBOL_COMPLETE="●" # Filled circle
export SYMBOL_ARROW="→"    # Right arrow
export SYMBOL_INFO="ℹ"     # Information
export SYMBOL_WARN="⚠"     # Warning triangle

# Detect capabilities
HAS_GUM=false
HAS_TTY=false
USE_GUM=false

if command -v gum &> /dev/null; then
    HAS_GUM=true
fi

if [ -t 0 ] && [ -t 1 ]; then
    HAS_TTY=true
fi

# Use gum only if we have both gum and a TTY
if $HAS_GUM && $HAS_TTY; then
    USE_GUM=true
fi

# Export for use in other scripts
export HAS_GUM HAS_TTY USE_GUM

# Offer to install gum if not present (only once per session)
if ! $HAS_GUM && $HAS_TTY && [[ -z "${GUM_INSTALL_OFFERED:-}" ]]; then
    export GUM_INSTALL_OFFERED=1
    
    echo ""
    echo "Enhanced UI available with 'gum' - install for better experience?"
    read -p "Install gum? [y/N]: " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v brew &> /dev/null; then
            echo "Installing via brew..."
            brew install gum && HAS_GUM=true && USE_GUM=true
        elif command -v apt-get &> /dev/null; then
            echo "Installing via apt..."
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
            echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
            sudo apt update && sudo apt install -y gum && HAS_GUM=true && USE_GUM=true
        else
            echo "Please install gum manually: https://github.com/charmbracelet/gum"
        fi
    fi
fi

# ============================================================================
# Text Styling Functions
# ============================================================================

print_banner() {
    local title="${1:-n8n Production Deployment}"
    local subtitle="${2:-By David Nagtzaam}"
    local url="${3:-davidnagtzaam.com}"
    
    if $USE_GUM; then
        gum style \
            --foreground 212 \
            --border-foreground 57 \
            --border rounded \
            --align center \
            --width 62 \
            --margin "1 0" \
            --padding "1 2" \
            --bold \
            "$title" \
            "" \
            "$subtitle" \
            "$url"
    else
        echo ""
        echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${MAGENTA}${BOLD}║                                                          ║${NC}"
        echo -e "${MAGENTA}${BOLD}║          $title${NC}"
        echo -e "${MAGENTA}${BOLD}║                                                          ║${NC}"
        echo -e "${MAGENTA}${BOLD}║              $subtitle${NC}"
        echo -e "${MAGENTA}${BOLD}║              $url                           ║${NC}"
        echo -e "${MAGENTA}${BOLD}║                                                          ║${NC}"
        echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
        echo ""
    fi
}

print_header() {
    local text="$1"
    echo ""
    if $USE_GUM; then
        gum style \
            --foreground 212 \
            --border-foreground 212 \
            --border double \
            --align center \
            --width 60 \
            --margin "1 0" \
            --padding "1 2" \
            "$text"
    else
        echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${MAGENTA}${BOLD}  $text${NC}"
        echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
    echo ""
}

print_success() {
    if $USE_GUM; then
        gum style --foreground 2 "[OK] $1"
    else
        echo -e "${GREEN}[OK] $1${NC}"
    fi
}

print_error() {
    if $USE_GUM; then
        gum style --foreground 1 --bold "[ERROR] $1"
    else
        echo -e "${RED}${BOLD}[ERROR] $1${NC}"
    fi
}

print_warning() {
    if $USE_GUM; then
        gum style --foreground 3 "[WARN] $1"
    else
        echo -e "${YELLOW}[WARN] $1${NC}"
    fi
}

print_info() {
    if $USE_GUM; then
        gum style --foreground 6 "[INFO] $1"
    else
        echo -e "${CYAN}[INFO] $1${NC}"
    fi
}

print_step() {
    if $USE_GUM; then
        gum style --foreground 5 "→ $1"
    else
        echo -e "${BLUE}→ $1${NC}"
    fi
}

print_dim() {
    if $USE_GUM; then
        gum style --foreground 8 "$1"
    else
        echo -e "${DIM}$1${NC}"
    fi
}

# ============================================================================
# Interactive Input Functions
# ============================================================================

prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local placeholder="${3:-Enter value}"
    
    if $USE_GUM; then
        local gum_args=(--placeholder="$placeholder")
        if [[ -n "$default" ]]; then
            gum_args+=(--value="$default")
        fi
        gum_args+=(--prompt="$(gum style --foreground 6 "$prompt: ")")
        gum input "${gum_args[@]}"
    else
        local value
        if [[ -n "$default" ]]; then
            read -p "$(echo -e "${CYAN}$prompt ${NC}[${YELLOW}$default${NC}]: ")" value
            echo "${value:-$default}"
        else
            read -p "$(echo -e "${CYAN}$prompt: ${NC}")" value
            echo "$value"
        fi
    fi
}

prompt_password() {
    local prompt="$1"
    local placeholder="${2:-Enter password}"
    
    if $USE_GUM; then
        gum input --password \
            --placeholder="$placeholder" \
            --prompt="$(gum style --foreground 6 "$prompt: ")"
    else
        local value
        read -s -p "$(echo -e "${CYAN}$prompt: ${NC}")" value
        echo "" >&2  # Newline for terminal feedback
        echo "$value"
    fi
}

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    
    if $USE_GUM; then
        if [[ "$default" == "y" ]]; then
            gum confirm "$prompt" --default=true && echo "y" || echo "n"
        else
            gum confirm "$prompt" --default=false && echo "y" || echo "n"
        fi
        return 0
    else
        local value
        if [[ "$default" == "y" ]]; then
            read -p "$(echo -e "${CYAN}$prompt ${NC}[${GREEN}Y${NC}/${RED}n${NC}]: ")" value
            value="${value:-y}"
        else
            read -p "$(echo -e "${CYAN}$prompt ${NC}[${RED}y${NC}/${GREEN}N${NC}]: ")" value
            value="${value:-n}"
        fi
        
        [[ "$value" =~ ^[Yy]$ ]]
    fi
}

prompt_choice() {
    local prompt="$1"
    shift
    local options=("$@")
    
    if $USE_GUM; then
        gum choose --header="$(gum style --foreground 212 --bold "$prompt")" \
            --cursor.foreground="212" \
            --height=15 \
            "${options[@]}"
    else
        echo -e "${CYAN}${BOLD}$prompt${NC}"
        select choice in "${options[@]}"; do
            if [[ -n "$choice" ]]; then
                echo "$choice"
                return 0
            fi
        done
    fi
}

prompt_multi_choice() {
    local prompt="$1"
    shift
    local options=("$@")
    
    if $USE_GUM; then
        gum choose --header="$(gum style --foreground 212 --bold "$prompt")" \
            --cursor.foreground="212" \
            --height=15 \
            --no-limit \
            "${options[@]}"
    else
        echo -e "${CYAN}${BOLD}$prompt${NC}"
        echo -e "${DIM}(Enter numbers separated by spaces, e.g., '1 3 4')${NC}"
        local i=1
        for option in "${options[@]}"; do
            echo "$i) $option"
            ((i++))
        done
        
        read -p "$(echo -e ${CYAN}Select options: ${NC})" selections
        
        # Convert selections to option names
        local selected=()
        for num in $selections; do
            if [[ $num =~ ^[0-9]+$ ]] && [ $num -ge 1 ] && [ $num -le ${#options[@]} ]; then
                selected+=("${options[$((num-1))]}")
            fi
        done
        
        printf '%s\n' "${selected[@]}"
    fi
}

# ============================================================================
# Progress & Status Functions
# ============================================================================

show_spinner() {
    local message="$1"
    shift
    local cmd=("$@")
    
    if $USE_GUM; then
        gum spin --spinner dot \
            --title="$message" \
            --show-output \
            -- "${cmd[@]}"
    else
        echo -e "${CYAN}⏳ $message...${NC}"
        "${cmd[@]}"
    fi
}

show_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Processing}"
    
    if $USE_GUM; then
        local percentage=$((current * 100 / total))
        gum style --foreground 6 "$(printf '%-50s' "$message") [$current/$total] ${percentage}%"
    else
        echo -e "${CYAN}$message [$current/$total]${NC}"
    fi
}

# ============================================================================
# Formatting Functions
# ============================================================================

format_table() {
    if $USE_GUM; then
        gum table --border rounded --border.foreground 212
    else
        column -t -s $'\t'
    fi
}

format_code() {
    local code="$1"
    local language="${2:-bash}"
    
    if $USE_GUM; then
        echo "$code" | gum format -t code -l "$language"
    else
        echo -e "${GREEN}$code${NC}"
    fi
}

format_markdown() {
    local text="$1"
    
    if $USE_GUM; then
        echo "$text" | gum format -t markdown
    else
        echo "$text"
    fi
}

# ============================================================================
# Utility Functions
# ============================================================================

pause() {
    local message="${1:-Press any key to continue...}"
    
    if $USE_GUM; then
        gum style --foreground 8 "$message"
        read -n 1 -s -r
    else
        echo -e "${DIM}$message${NC}"
        read -n 1 -s -r
    fi
    echo ""
}

show_tip() {
    if ! $HAS_GUM && $HAS_TTY; then
        echo ""
        print_info "💡 Tip: Install 'gum' for an enhanced experience: https://github.com/charmbracelet/gum"
        echo ""
    fi
}

# ============================================================================
# Startup Message
# ============================================================================

# Show gum detection status when library is sourced (optional, can be disabled)
if [[ "${UI_LIB_QUIET:-false}" != "true" ]]; then
    if $USE_GUM; then
        : # Silent when gum is available
    elif ! $HAS_TTY; then
        : # Silent in non-interactive mode
    fi
fi

# ============================================================================
# Export all functions
# ============================================================================

export -f print_banner
export -f print_header
export -f print_success
export -f print_error
export -f print_warning
export -f print_info
export -f print_step
export -f print_dim
export -f prompt_input
export -f prompt_password
export -f prompt_yes_no
export -f prompt_choice
export -f prompt_multi_choice
export -f show_spinner
export -f show_progress
export -f format_table
export -f format_code
export -f format_markdown
export -f pause
export -f show_tip
