#!/usr/bin/env bash
# ============================================================================
# n8nctl - Configuration Management Library
# ============================================================================
# Created by: David Nagtzaam - https://davidnagtzaam.com
#
# Handles user configuration following XDG Base Directory Specification
# Config location: ~/.config/n8nctl/config
#
# This is a standalone module that can be sourced independently
# ============================================================================

# ============================================================================
# Configuration Paths
# ============================================================================

# Follow XDG Base Directory Specification
N8NCTL_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/n8nctl"
N8NCTL_CONFIG_FILE="$N8NCTL_CONFIG_DIR/config"

# ============================================================================
# Configuration Functions
# ============================================================================

# Initialize config directory and file
config_init() {
    if [ ! -d "$N8NCTL_CONFIG_DIR" ]; then
        mkdir -p "$N8NCTL_CONFIG_DIR"
        chmod 700 "$N8NCTL_CONFIG_DIR"
    fi
    
    if [ ! -f "$N8NCTL_CONFIG_FILE" ]; then
        cat > "$N8NCTL_CONFIG_FILE" <<'EOF'
# n8nctl configuration file
# This file is automatically managed by n8nctl
# Manual edits are preserved unless they conflict with tool operations

# UI Mode: bashing (with gum) or basic (without gum)
# Values: bashing, basic, auto
# auto = prompt user on first run
ui_mode=auto
EOF
        chmod 600 "$N8NCTL_CONFIG_FILE"
    fi
}

# Get configuration value
# Usage: config_get "key" [default_value]
config_get() {
    local key="$1"
    local default="${2:-}"
    
    config_init
    
    if [ -f "$N8NCTL_CONFIG_FILE" ]; then
        local value
        value=$(grep -E "^${key}=" "$N8NCTL_CONFIG_FILE" 2>/dev/null | cut -d= -f2- | tail -1)
        if [ -n "$value" ]; then
            echo "$value"
            return 0
        fi
    fi
    
    echo "$default"
    return 1
}

# Set configuration value
# Usage: config_set "key" "value"
config_set() {
    local key="$1"
    local value="$2"
    
    config_init
    
    # Check if key exists
    if grep -q "^${key}=" "$N8NCTL_CONFIG_FILE" 2>/dev/null; then
        # Update existing key (cross-platform sed)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^${key}=.*|${key}=${value}|" "$N8NCTL_CONFIG_FILE"
        else
            sed -i "s|^${key}=.*|${key}=${value}|" "$N8NCTL_CONFIG_FILE"
        fi
    else
        # Append new key
        echo "${key}=${value}" >> "$N8NCTL_CONFIG_FILE"
    fi
}

# Check if a key exists in config
# Usage: config_exists "key"
config_exists() {
    local key="$1"
    
    if [ ! -f "$N8NCTL_CONFIG_FILE" ]; then
        return 1
    fi
    
    grep -q "^${key}=" "$N8NCTL_CONFIG_FILE" 2>/dev/null
}

# Get config file path (for debugging)
config_path() {
    echo "$N8NCTL_CONFIG_FILE"
}

# Export functions and variables for use in other scripts
export N8NCTL_CONFIG_DIR N8NCTL_CONFIG_FILE
export -f config_init config_get config_set config_exists config_path
