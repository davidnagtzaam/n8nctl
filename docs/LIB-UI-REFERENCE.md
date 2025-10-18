# lib-ui.sh Framework - Quick Reference Guide

## Overview
A production-ready bash UI library with automatic gum (Charm.sh) integration and fallbacks.

## Installation in New Scripts

```bash
#!/usr/bin/env bash
set -euo pipefail

# Load shared UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-ui.sh"

# Your script starts here...
```

## Available Functions

### 📋 Informational Output

#### `print_banner "Title" "Subtitle" "URL"`
```bash
print_banner "n8n Production Deployment" "By David Nagtzaam" "davidnagtzaam.com"
# Creates a fancy bordered banner (gum) or ASCII box (fallback)
```

#### `print_header "Section Title"`
```bash
print_header "Database Configuration"
# Creates a section header with horizontal lines
```

#### `print_success "Message"`
```bash
print_success "Installation complete!"
# Displays: ✅ Installation complete! (in green)
```

#### `print_error "Message"`
```bash
print_error "Connection failed"
# Displays: ❌ Connection failed (in red)
```

#### `print_warning "Message"`
```bash
print_warning "This action cannot be undone"
# Displays: ⚠️  This action cannot be undone (in yellow)
```

#### `print_info "Message"`
```bash
print_info "Processing 5 files..."
# Displays: ℹ️  Processing 5 files... (in cyan)
```

#### `print_step "Step description"`
```bash
print_step "Installing dependencies"
# Displays: → Installing dependencies (in cyan, dimmed)
```

### 💬 Interactive Input

#### `prompt_input "Prompt" "Default" "Placeholder"`
```bash
NAME=$(prompt_input "Enter your name" "John Doe")
# With gum: Fancy input box with placeholder
# Without gum: Enter your name [John Doe]: _

DATABASE_URL=$(prompt_input "Database URL" "" "postgresql://...")
# Empty default, custom placeholder
```

#### `prompt_password "Prompt" "Placeholder"`
```bash
PASSWORD=$(prompt_password "Enter password")
# With gum: Masked input (dots)
# Without gum: Silent input (no echo)
```

#### `prompt_yes_no "Question" "default"`
```bash
if prompt_yes_no "Continue with installation?" "y"; then
    echo "Proceeding..."
else
    echo "Cancelled"
fi

# Default "y": [Y/n]
# Default "n": [y/N]
# Returns true (0) for yes, false (1) for no
```

#### `prompt_choice "Prompt" "option1" "option2" "option3"...`
```bash
CHOICE=$(prompt_choice "Select environment" "Development" "Staging" "Production")
echo "Selected: $CHOICE"

# With gum: Interactive selection menu
# Without gum: numbered list with input
```

#### `prompt_multi_choice "Prompt" "option1" "option2"...`
```bash
SELECTED=$(prompt_multi_choice "Select features" "SSL" "Monitoring" "Backups" "Analytics")
echo "Selected: $SELECTED"

# With gum: Multi-select with spacebar
# Without gum: Comma-separated input
```

### ⏳ Execution Feedback

#### `show_spinner "Message" command arg1 arg2...`
```bash
show_spinner "Installing packages" apt-get install -y nginx
show_spinner "Building project" make build

# With gum: Animated spinner
# Without gum: Simple text + command execution
```

## Color Variables

When fallback mode is active, these are available:
```bash
$RED       # \033[0;31m
$GREEN     # \033[0;32m
$YELLOW    # \033[1;33m
$BLUE      # \033[0;34m
$CYAN      # \033[0;36m
$MAGENTA   # \033[0;35m
$BOLD      # \033[1m
$DIM       # \033[2m
$NC        # \033[0m (No Color)
```

## Environment Detection

Three exported boolean variables:
```bash
$HAS_GUM    # true if gum is installed
$HAS_TTY    # true if running in a terminal
$USE_GUM    # true if both HAS_GUM and HAS_TTY are true
```

## Complete Example Script

```bash
#!/usr/bin/env bash
# ============================================================================
# My Deployment Script
# ============================================================================
set -euo pipefail

# Load shared UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-ui.sh"

# Main function
main() {
    clear
    print_banner "My Application Installer" "Version 1.0" "example.com"
    
    # Gather information
    print_header "Configuration"
    APP_NAME=$(prompt_input "Application name" "my-app")
    PORT=$(prompt_input "Port number" "3000")
    DOMAIN=$(prompt_input "Domain name" "")
    
    # Confirm
    print_header "Review Configuration"
    echo "Application: $APP_NAME"
    echo "Port: $PORT"
    echo "Domain: $DOMAIN"
    echo ""
    
    if ! prompt_yes_no "Proceed with installation?" "y"; then
        print_warning "Installation cancelled"
        exit 0
    fi
    
    # Execute steps
    print_header "Installation"
    
    print_step "Creating directories"
    mkdir -p "/opt/$APP_NAME"
    print_success "Directories created"
    
    print_step "Installing dependencies"
    show_spinner "Installing packages" apt-get update -qq
    show_spinner "Installing nodejs" apt-get install -y nodejs npm
    print_success "Dependencies installed"
    
    print_step "Configuring application"
    cat > "/opt/$APP_NAME/.env" << EOF
APP_NAME=$APP_NAME
PORT=$PORT
DOMAIN=$DOMAIN
EOF
    print_success "Configuration saved"
    
    # Summary
    print_header "Installation Complete! 🎉"
    print_success "Application installed successfully"
    print_info "Application directory: /opt/$APP_NAME"
    print_info "Configuration file: /opt/$APP_NAME/.env"
    echo ""
    print_warning "Don't forget to start your application!"
}

# Run main function
main "$@"
```

## Best Practices

### 1. Always Use `set -euo pipefail`
```bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures
```

### 2. Structure Your Script
```bash
# 1. Shebang and header
# 2. Set options
# 3. Source lib-ui.sh
# 4. Define variables
# 5. Define functions
# 6. Main execution
```

### 3. Error Handling
```bash
if ! some_command; then
    print_error "Command failed"
    exit 1
fi
```

### 4. Use Functions for Complex Logic
```bash
validate_input() {
    local input="$1"
    if [[ -z "$input" ]]; then
        print_error "Input cannot be empty"
        return 1
    fi
    return 0
}
```

### 5. Provide Feedback
```bash
print_step "Starting process"
show_spinner "Processing data" process_data
print_success "Process complete"
```

## Installing Gum (Optional)

For the best experience, install gum:

### macOS
```bash
brew install gum
```

### Ubuntu/Debian
```bash
echo "deb [trusted=yes] https://repo.charm.sh/apt/ /" | sudo tee /etc/apt/sources.list.d/charm.list
sudo apt update && sudo apt install gum
```

### Go Install
```bash
go install github.com/charmbracelet/gum@latest
```

Without gum, all functions still work with terminal-friendly fallbacks.

## Troubleshooting

### Scripts hang on prompts
**Cause**: Running in non-interactive mode (CI/CD, cron)  
**Solution**: Provide all inputs via environment variables or flags

### Colors not showing
**Cause**: No TTY detected  
**Solution**: This is expected. Output will be plain text.

### Gum not detected but is installed
**Cause**: Not in PATH  
**Solution**: Add gum installation directory to PATH

## Links

- Gum Repository: https://github.com/charmbracelet/gum
- Charm.sh: https://charm.sh
- This Framework: Part of n8nctl project by David Nagtzaam

---

**Framework Version**: 1.0  
**Last Updated**: October 17, 2025  
**License**: Same as parent project
