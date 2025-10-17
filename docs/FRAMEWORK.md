# Framework Guide - Reusable Script Framework

This document explains how to use the n8n-deploy project structure as a framework for creating your own automation scripts.

## 📁 Project Structure

```
your-project/
├── lib/                        # 🎨 REUSABLE: Framework components
│   ├── ui.sh                  # Terminal UI framework
│   └── README.md              # Framework documentation
│
├── scripts/                    # 📝 PROJECT-SPECIFIC: Your automation scripts
│   ├── install.sh             # Example: Installation script
│   ├── configure.sh           # Example: Configuration script
│   ├── backup.sh              # Example: Backup script
│   └── myctl                  # Example: CLI control tool
│
├── examples/                   # 💡 OPTIONAL: Demo/example scripts
│   └── demo-ui.sh             # UI framework demo
│
├── config/                     # ⚙️ PROJECT-SPECIFIC: Configuration files
│   └── .env.template          # Environment template
│
├── docs/                       # 📚 OPTIONAL: Additional documentation
│   └── API.md                 # Your API docs
│
├── README.md                   # Project overview
├── FRAMEWORK.md               # This file
└── LICENSE                    # License file
```

## 🎯 Core Principles

### 1. Separation of Concerns

**lib/**: Reusable, project-agnostic framework code
- Can be copied to any project
- No project-specific logic
- Well-documented APIs
- Battle-tested

**scripts/**: Project-specific automation
- Uses lib/ framework
- Contains business logic
- Project-specific workflows
- Uses consistent UI from lib/

### 2. Consistent User Experience

All scripts use the same UI framework:
- Same prompts and messages
- Same colors and styling
- Same error handling
- Same confirmation patterns

Result: Professional, cohesive toolset

### 3. Framework First

When creating new scripts:
1. Think "Can this be in lib/?" (reusable)
2. If yes → Add to lib/
3. If no → Put in scripts/ and use lib/

## 🚀 Quick Start - Creating New Projects

### Option 1: Copy Framework Structure

```bash
# Create new project
mkdir my-automation-project
cd my-automation-project

# Copy the framework
cp -r /path/to/n8n-deploy/lib ./
cp -r /path/to/n8n-deploy/examples ./

# Create your scripts directory
mkdir scripts

# Create your first script
nano scripts/install.sh
```

### Option 2: Use as Template

```bash
# Clone/copy entire n8n-deploy
cp -r /path/to/n8n-deploy my-automation-project
cd my-automation-project

# Remove n8n-specific scripts, keep framework
rm scripts/{init,backup,restore,upgrade,healthcheck,preflight,n8nctl}.sh

# Keep framework
# lib/ stays
# examples/ stays

# Add your scripts
nano scripts/my-script.sh
```

## 📝 Creating Your First Script

### Step 1: Script Template

```bash
#!/usr/bin/env bash
# ============================================================================
# My Automation Script
# ============================================================================
# Description: Brief description of what this does
# Author: Your Name
# Website: your-site.com
# ============================================================================

set -euo pipefail

# Load framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/ui.sh"

# Global variables
APP_NAME="myapp"
VERSION="1.0.0"

# ============================================================================
# Functions
# ============================================================================

show_welcome() {
    clear
    print_banner "$APP_NAME Setup" "Version $VERSION" "your-site.com"
}

collect_config() {
    print_header "Configuration"
    
    APP_NAME=$(prompt_input "Application name" "myapp")
    DOMAIN=$(prompt_input "Domain name" "example.com")
    PORT=$(prompt_input "Port" "3000")
}

confirm_settings() {
    print_header "Review Configuration"
    
    echo "Application: $APP_NAME"
    echo "Domain: $DOMAIN"
    echo "Port: $PORT"
    echo ""
    
    if ! prompt_yes_no "Proceed with installation?" "y"; then
        print_warning "Installation cancelled"
        exit 0
    fi
}

perform_installation() {
    print_header "Installation"
    
    print_step "Creating directories"
    mkdir -p "/opt/$APP_NAME"
    print_success "Directories created"
    
    print_step "Installing dependencies"
    show_spinner "Installing packages" apt-get install -y nginx
    print_success "Dependencies installed"
    
    print_step "Configuring application"
    cat > "/opt/$APP_NAME/.env" << EOF
APP_NAME=$APP_NAME
DOMAIN=$DOMAIN
PORT=$PORT
EOF
    print_success "Configuration saved"
}

show_summary() {
    print_header "Installation Complete! 🎉"
    
    print_success "Application installed successfully"
    print_info "Location: /opt/$APP_NAME"
    print_info "Config: /opt/$APP_NAME/.env"
    echo ""
    print_warning "Next steps:"
    echo "  1. Review configuration"
    echo "  2. Start the application"
    echo "  3. Configure firewall"
}

# ============================================================================
# Main
# ============================================================================

main() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
    
    # Execute workflow
    show_welcome
    collect_config
    confirm_settings
    perform_installation
    show_summary
}

# Run main function
main "$@"
```

### Step 2: Make Executable

```bash
chmod +x scripts/my-script.sh
```

### Step 3: Test

```bash
sudo bash scripts/my-script.sh
```

## 🎨 Using the UI Framework

### Available Functions

#### Display Functions

```bash
# Headers and sections
print_banner "Title" "Subtitle" "URL"
print_header "Section Name"

# Status messages
print_success "Operation completed"
print_error "Something failed"
print_warning "Be careful"
print_info "FYI: something"
print_step "Doing something"

# Custom styling
print_dim "Less important text"
```

#### Interactive Input

```bash
# Text input
NAME=$(prompt_input "Enter name" "default-value")

# Password input
PASSWORD=$(prompt_password "Enter password")

# Confirmation
if prompt_yes_no "Continue?" "y"; then
    echo "User said yes"
fi

# Single choice
ENV=$(prompt_choice "Select environment" "Dev" "Staging" "Prod")

# Multiple choice
FEATURES=$(prompt_multi_choice "Select features" "SSL" "Backups" "Monitoring")
```

#### Execution Feedback

```bash
# Run command with spinner
show_spinner "Installing packages" apt-get install -y nginx

# Run long command
show_spinner "Building project" make build
```

### Best Practices

```bash
# 1. Always validate input
VALUE=$(prompt_input "Enter value" "")
while [[ -z "$VALUE" ]]; do
    print_error "Value cannot be empty"
    VALUE=$(prompt_input "Enter value" "")
done

# 2. Confirm destructive actions
if prompt_yes_no "Delete all data?" "n"; then
    print_warning "Deleting data..."
    # Do dangerous thing
fi

# 3. Provide feedback
print_step "Starting process"
# Do thing
print_success "Process complete"

# 4. Handle errors gracefully
if ! some_command; then
    print_error "Command failed"
    exit 1
fi

# 5. Structure for clarity
main() {
    show_welcome
    gather_config
    confirm_config
    execute_installation
    show_summary
}
```

## 🛠️ Creating a CLI Control Tool (like n8nctl)

### Step 1: Basic Structure

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/ui.sh"

print_help() {
    echo "Usage: myctl <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start      Start services"
    echo "  stop       Stop services"
    echo "  status     Show status"
    echo "  logs       View logs"
    echo "  help       Show this help"
}

cmd_start() {
    print_info "Starting services..."
    show_spinner "Starting" systemctl start myapp
    print_success "Services started"
}

cmd_stop() {
    print_info "Stopping services..."
    show_spinner "Stopping" systemctl stop myapp
    print_success "Services stopped"
}

cmd_status() {
    systemctl status myapp
}

cmd_logs() {
    journalctl -u myapp -f
}

main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        start) cmd_start "$@" ;;
        stop) cmd_stop "$@" ;;
        status) cmd_status "$@" ;;
        logs) cmd_logs "$@" ;;
        help|--help|-h) print_help ;;
        *)
            print_error "Unknown command: $command"
            print_help
            exit 1
            ;;
    esac
}

main "$@"
```

### Step 2: Make It Global

```bash
# Install to system path
sudo ln -s /path/to/your/scripts/myctl /usr/local/bin/myctl

# Now use from anywhere
myctl start
myctl status
```

## 📦 Real-World Examples

### Example 1: Server Setup Script

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/ui.sh"

main() {
    clear
    print_banner "Server Setup" "v1.0" "example.com"
    
    # Collect info
    print_header "Configuration"
    HOSTNAME=$(prompt_input "Server hostname" "")
    ADMIN_EMAIL=$(prompt_input "Admin email" "")
    
    # Install packages
    print_header "Installing Software"
    
    print_step "Updating system"
    show_spinner "apt update" apt-get update -qq
    
    print_step "Installing nginx"
    show_spinner "apt install nginx" apt-get install -y nginx
    
    print_step "Installing docker"
    show_spinner "Installing docker" curl -fsSL https://get.docker.com | sh
    
    print_success "All packages installed"
    
    # Configure
    print_header "Configuration"
    
    print_step "Setting hostname"
    hostnamectl set-hostname "$HOSTNAME"
    print_success "Hostname set to $HOSTNAME"
    
    # Summary
    print_header "Setup Complete!"
    print_success "Server is ready"
    print_info "Hostname: $HOSTNAME"
    print_info "Admin: $ADMIN_EMAIL"
}

main "$@"
```

### Example 2: Database Backup Script

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/ui.sh"

BACKUP_DIR="/var/backups/db"
DB_NAME="myapp"

main() {
    print_banner "Database Backup" "v1.0"
    
    # Confirm
    if ! prompt_yes_no "Create backup of $DB_NAME?" "y"; then
        print_info "Backup cancelled"
        exit 0
    fi
    
    # Create backup
    print_header "Creating Backup"
    
    mkdir -p "$BACKUP_DIR"
    
    BACKUP_FILE="$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).sql.gz"
    
    print_step "Dumping database"
    show_spinner "Creating backup" \
        pg_dump "$DB_NAME" | gzip > "$BACKUP_FILE"
    
    print_success "Backup created: $BACKUP_FILE"
    
    # Cleanup old backups
    print_step "Cleaning old backups"
    find "$BACKUP_DIR" -name "backup-*.sql.gz" -mtime +30 -delete
    print_success "Old backups removed"
    
    # Summary
    print_header "Backup Complete!"
    print_success "Database backed up successfully"
    print_info "Location: $BACKUP_FILE"
    print_info "Size: $(du -h "$BACKUP_FILE" | cut -f1)"
}

main "$@"
```

### Example 3: Multi-App Installer

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/ui.sh"

main() {
    clear
    print_banner "Application Installer" "v1.0"
    
    # Select apps
    print_header "Select Applications"
    
    APPS=$(prompt_multi_choice "Select applications to install" \
        "nginx" \
        "postgresql" \
        "redis" \
        "docker" \
        "nodejs")
    
    # Confirm
    print_header "Review Selection"
    echo "Apps to install: $APPS"
    echo ""
    
    if ! prompt_yes_no "Proceed with installation?" "y"; then
        print_info "Installation cancelled"
        exit 0
    fi
    
    # Install each app
    print_header "Installation"
    
    IFS=',' read -ra APP_ARRAY <<< "$APPS"
    for app in "${APP_ARRAY[@]}"; do
        app=$(echo "$app" | xargs)  # Trim whitespace
        
        print_step "Installing $app"
        case "$app" in
            nginx)
                show_spinner "Installing nginx" apt-get install -y nginx
                ;;
            postgresql)
                show_spinner "Installing postgresql" apt-get install -y postgresql
                ;;
            redis)
                show_spinner "Installing redis" apt-get install -y redis-server
                ;;
            docker)
                show_spinner "Installing docker" curl -fsSL https://get.docker.com | sh
                ;;
            nodejs)
                show_spinner "Installing nodejs" apt-get install -y nodejs npm
                ;;
        esac
        print_success "$app installed"
    done
    
    # Summary
    print_header "Installation Complete! 🎉"
    print_success "All applications installed"
    echo ""
    print_info "Installed applications:"
    for app in "${APP_ARRAY[@]}"; do
        echo "  • $app"
    done
}

main "$@"
```

## 🎓 Advanced Patterns

### Pattern 1: Configuration Management

```bash
CONFIG_FILE="/etc/myapp/config.env"

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        print_success "Configuration loaded"
    else
        print_warning "No configuration found, using defaults"
    fi
}

save_config() {
    cat > "$CONFIG_FILE" << EOF
APP_NAME="$APP_NAME"
DOMAIN="$DOMAIN"
PORT="$PORT"
EOF
    print_success "Configuration saved"
}
```

### Pattern 2: Error Recovery

```bash
cleanup() {
    if [[ $? -ne 0 ]]; then
        print_error "Script failed, cleaning up..."
        # Cleanup code here
    fi
}

trap cleanup EXIT
```

### Pattern 3: Progress Tracking

```bash
total_steps=5
current_step=0

do_step() {
    current_step=$((current_step + 1))
    print_header "Step $current_step/$total_steps: $1"
}

main() {
    do_step "Update system"
    apt-get update
    
    do_step "Install packages"
    apt-get install -y nginx
    
    do_step "Configure"
    # Configure
    
    do_step "Test"
    # Test
    
    do_step "Finalize"
    # Finalize
}
```

### Pattern 4: Dry Run Mode

```bash
DRY_RUN=false

execute() {
    local cmd="$1"
    
    if $DRY_RUN; then
        print_info "[DRY RUN] Would execute: $cmd"
    else
        eval "$cmd"
    fi
}

# Usage
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    print_warning "Running in DRY RUN mode"
fi

execute "apt-get install nginx"
```

## 📚 Additional Resources

- **UI Framework Reference**: See `/lib/README.md`
- **Complete API**: See `/LIB-UI-REFERENCE.md`
- **Live Demo**: Run `/examples/demo-ui.sh`
- **Production Examples**: See n8n-deploy `/scripts/` directory
- **CLI Tool Example**: See n8n-deploy `/scripts/n8nctl`

## 🎯 Checklist for New Projects

- [ ] Copy `lib/` directory
- [ ] Create `scripts/` directory
- [ ] Create first script using template
- [ ] Test script with `bash -n script.sh`
- [ ] Make script executable
- [ ] Test in real environment
- [ ] Document usage in README.md
- [ ] Consider creating CLI tool (myctl)
- [ ] Add error handling
- [ ] Add configuration management
- [ ] Test in non-interactive mode
- [ ] Add to version control

## 💡 Tips for Success

1. **Start Simple**: Copy the basic template, add features incrementally
2. **Test Often**: Use `bash -n script.sh` to catch syntax errors early
3. **User Feedback**: Always provide feedback for every action
4. **Error Handling**: Assume things will fail, handle gracefully
5. **Documentation**: Document what each script does and how to use it
6. **Consistency**: Use the framework consistently across all scripts
7. **Examples**: Keep working examples in `/examples/` directory
8. **Version Control**: Track changes with git

## 🚫 Common Mistakes to Avoid

1. ❌ Not using `set -euo pipefail`
2. ❌ Running destructive actions without confirmation
3. ❌ No user feedback during long operations
4. ❌ Not validating user input
5. ❌ Mixing framework code with business logic
6. ❌ Forgetting to handle non-interactive mode
7. ❌ Not testing scripts before deployment
8. ❌ Hardcoding configuration values

## 🎉 You're Ready!

You now have a solid framework for creating professional, consistent automation scripts. The framework handles the UI, input validation, and user experience - you focus on the business logic.

Start creating your first script and enjoy the consistent, professional experience!

---

**Framework Version**: 1.0  
**Last Updated**: October 17, 2025  
**Based on**: n8n-deploy by David Nagtzaam  
**Website**: https://davidnagtzaam.com
