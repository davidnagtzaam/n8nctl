#!/usr/bin/env bash
# ============================================================================
# n8n Production Deployment - Interactive Setup Wizard
# ============================================================================
# Created by: David Nagtzaam - https://davidnagtzaam.com
#
# This script provides an interactive setup experience that:
# - Collects configuration parameters
# - Generates secure encryption keys
# - Creates .env file from template
# - Sets up systemd service
# - Initializes the deployment
# ============================================================================

set -euo pipefail

# Load shared UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/lib-ui.sh"

# Variables
generate_random_string() {
    local length="${1:-32}"
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# ============================================================================
# Configuration Collection
# ============================================================================

collect_domain_config() {
    print_header "Domain & HTTPS Configuration"
    
    print_info "Enter the domain where n8n will be accessible."
    print_info "Example: flows.example.com"
    print_warning "Make sure your DNS A record points to this server!"
    echo ""
    
    N8N_HOST=$(prompt_input "Domain" "")
    while [[ -z "$N8N_HOST" ]]; do
        print_error "Domain is required"
        N8N_HOST=$(prompt_input "Domain" "")
    done
    
    N8N_PROTOCOL="https"
    WEBHOOK_URL="https://${N8N_HOST}/"
    N8N_EDITOR_BASE_URL="https://${N8N_HOST}/"
    
    echo ""
    TRAEFIK_ACME_EMAIL=$(prompt_input "Email for Let's Encrypt certificates" "admin@${N8N_HOST}")
    
    print_success "Domain configured: $N8N_HOST"
}

collect_database_config() {
    print_header "Database Configuration"
    
    print_info "Choose your PostgreSQL setup:"
    echo ""
    echo "  1) Local PostgreSQL (managed by Docker)"
    echo "     - Best for: Development, small deployments"
    echo "     - Pros: Easy setup, no external dependencies"
    echo "     - Cons: Single point of failure, manual backups"
    echo ""
    echo "  2) External PostgreSQL (Supabase, AWS RDS, etc.)"
    echo "     - Best for: Production, high availability"
    echo "     - Pros: Managed backups, better reliability, scaling"
    echo "     - Cons: Requires setup, may have costs"
    echo ""
    
    read -p $'\033[0;36mSelect option \033[0m[\033[1;33m1\033[0m]: ' DB_CHOICE
    DB_CHOICE="${DB_CHOICE:-1}"
    
    if [[ "$DB_CHOICE" == "2" ]]; then
        USE_EXTERNAL_DB=true
        echo ""
        print_info "External PostgreSQL configuration"
        print_info "Format: postgresql://user:password@host:port/database"
        print_info "Example: postgresql://n8n:secret@db.example.com:5432/n8n"
        echo ""
        
        DATABASE_URL=$(prompt_input "Database URL" "")
        while [[ -z "$DATABASE_URL" ]]; do
            print_error "Database URL is required"
            DATABASE_URL=$(prompt_input "Database URL" "")
        done
        
        # Set placeholders for local DB vars (won't be used)
        POSTGRES_USER="n8n"
        POSTGRES_PASSWORD="not_used_external_db"
        POSTGRES_DB="n8n"
        POSTGRES_HOST="not_used_external_db"
        POSTGRES_PORT="5432"
        
        print_success "External PostgreSQL configured"
    else
        USE_EXTERNAL_DB=false
        echo ""
        print_info "Local PostgreSQL configuration"
        echo ""
        
        POSTGRES_USER=$(prompt_input "PostgreSQL username" "n8n")
        POSTGRES_PASSWORD=$(prompt_password "PostgreSQL password (will be hidden)")
        while [[ -z "$POSTGRES_PASSWORD" ]]; do
            print_error "Password is required"
            POSTGRES_PASSWORD=$(prompt_password "PostgreSQL password (will be hidden)")
        done
        
        POSTGRES_DB=$(prompt_input "PostgreSQL database name" "n8n")
        POSTGRES_HOST="postgres"
        POSTGRES_PORT="5432"
        DATABASE_URL=""
        
        print_success "Local PostgreSQL configured"
    fi
}

collect_storage_config() {
    print_header "Binary Storage Configuration"
    
    print_info "n8n stores binary data (files, images) in storage."
    print_info "Choose your storage backend:"
    echo ""
    echo "  1) Local filesystem storage"
    echo "     - Best for: Development, small deployments"
    echo "     - Pros: Simple, no external dependencies, no costs"
    echo "     - Cons: Limited by disk space, no redundancy"
    echo ""
    echo "  2) S3-compatible storage (Recommended for production)"
    echo "     - Providers: Backblaze B2, AWS S3, Wasabi, MinIO, Cloudflare R2"
    echo "     - Pros: Scalable, redundant, offsite backups"
    echo "     - Cons: Requires setup, may have costs"
    echo ""
    
    read -p $'\033[0;36mSelect option \033[0m[\033[1;33m1\033[0m]: ' STORAGE_CHOICE
    STORAGE_CHOICE="${STORAGE_CHOICE:-1}"
    
    if [[ "$STORAGE_CHOICE" == "2" ]]; then
        # S3-compatible storage
        USE_LOCAL_STORAGE=false
        echo ""
        print_info "S3-compatible storage configuration"
        echo ""
        
        S3_ENDPOINT_URL=$(prompt_input "S3 Endpoint URL" "https://s3.us-west-002.backblazeb2.com")
        S3_BUCKET=$(prompt_input "S3 Bucket name" "n8n-binaries")
        S3_ACCESS_KEY_ID=$(prompt_input "S3 Access Key ID" "")
        while [[ -z "$S3_ACCESS_KEY_ID" ]]; do
            print_error "Access Key ID is required"
            S3_ACCESS_KEY_ID=$(prompt_input "S3 Access Key ID" "")
        done
        
        S3_SECRET_ACCESS_KEY=$(prompt_password "S3 Secret Access Key (will be hidden)")
        while [[ -z "$S3_SECRET_ACCESS_KEY" ]]; do
            print_error "Secret Access Key is required"
            S3_SECRET_ACCESS_KEY=$(prompt_password "S3 Secret Access Key (will be hidden)")
        done
        
        if prompt_yes_no "Force path style (required for MinIO, Backblaze)?" "y"; then
            S3_FORCE_PATH_STYLE="true"
        else
            S3_FORCE_PATH_STYLE="false"
        fi
        
        print_success "S3 storage configured"
    else
        # Local filesystem storage
        USE_LOCAL_STORAGE=true
        echo ""
        print_info "Local filesystem storage configuration"
        print_info "Files will be stored in Docker volume: n8n_data"
        echo ""
        
        # Set placeholder values for S3 variables (not used but needed in .env)
        S3_ENDPOINT_URL=""
        S3_BUCKET=""
        S3_ACCESS_KEY_ID=""
        S3_SECRET_ACCESS_KEY=""
        S3_FORCE_PATH_STYLE="false"
        
        print_success "Local storage configured"
    fi
}

collect_encryption_key() {
    print_header "Encryption Key"
    
    print_warning "The encryption key protects your n8n credentials."
    print_warning "If lost, your credentials cannot be recovered!"
    print_info "Recommendation: Auto-generate and save to password manager."
    echo ""
    
    if prompt_yes_no "Auto-generate encryption key?" "y"; then
        N8N_ENCRYPTION_KEY=$(generate_random_string 32)
        print_success "Encryption key generated"
    else
        N8N_ENCRYPTION_KEY=$(prompt_input "Enter your encryption key" "")
        while [[ -z "$N8N_ENCRYPTION_KEY" || ${#N8N_ENCRYPTION_KEY} -lt 24 ]]; do
            print_error "Encryption key must be at least 24 characters"
            N8N_ENCRYPTION_KEY=$(prompt_input "Enter your encryption key" "")
        done
    fi
    
    N8N_JWT_SECRET=$(generate_random_string 32)
}

collect_optional_config() {
    print_header "Optional Configuration"
    
    echo ""
    if prompt_yes_no "Configure SMTP for email notifications?" "n"; then
        CONFIGURE_SMTP=true
        N8N_EMAIL_MODE="smtp"
        N8N_SMTP_HOST=$(prompt_input "SMTP host" "smtp.gmail.com")
        N8N_SMTP_PORT=$(prompt_input "SMTP port" "587")
        N8N_SMTP_USER=$(prompt_input "SMTP username" "")
        N8N_SMTP_PASS=$(prompt_password "SMTP password (will be hidden)")
        N8N_SMTP_SENDER=$(prompt_input "Sender email" "$N8N_SMTP_USER")
        N8N_SMTP_SSL=$(prompt_yes_no "Use SSL?" "n" && echo "true" || echo "false")
    else
        CONFIGURE_SMTP=false
    fi
    
    echo ""
    GENERIC_TIMEZONE=$(prompt_input "Timezone" "$(timedatectl show --property=Timezone --value 2>/dev/null || echo 'UTC')")
}

# ============================================================================
# Environment File Creation
# ============================================================================

create_env_file() {
    print_header "Creating Configuration File"
    
    print_info "Generating .env file..."
    
    # Copy template
    cp "$ENV_TEMPLATE" "$ENV_FILE"
    
    # Replace values using sed (cross-platform compatible)
    sed_inline() {
        if sed --version 2>&1 | grep -q GNU; then
            sed -i "$@"
        else
            sed -i '' "$@"
        fi
    }
    
    # Core configuration
    sed_inline "s|N8N_HOST=.*|N8N_HOST=$N8N_HOST|" "$ENV_FILE"
    sed_inline "s|N8N_PROTOCOL=.*|N8N_PROTOCOL=$N8N_PROTOCOL|" "$ENV_FILE"
    sed_inline "s|WEBHOOK_URL=.*|WEBHOOK_URL=$WEBHOOK_URL|" "$ENV_FILE"
    sed_inline "s|N8N_ENCRYPTION_KEY=.*|N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY|" "$ENV_FILE"
    sed_inline "s|N8N_JWT_SECRET=.*|N8N_JWT_SECRET=$N8N_JWT_SECRET|" "$ENV_FILE"
    
    # Database configuration
    if [[ "$USE_EXTERNAL_DB" == true ]]; then
        sed_inline "s|#.*DATABASE_URL=.*|DATABASE_URL=$DATABASE_URL|" "$ENV_FILE"
        sed_inline "s|^DATABASE_URL=.*|DATABASE_URL=$DATABASE_URL|" "$ENV_FILE"
    else
        sed_inline "s|POSTGRES_USER=.*|POSTGRES_USER=$POSTGRES_USER|" "$ENV_FILE"
        sed_inline "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|" "$ENV_FILE"
        sed_inline "s|POSTGRES_DB=.*|POSTGRES_DB=$POSTGRES_DB|" "$ENV_FILE"
        sed_inline "s|POSTGRES_HOST=.*|POSTGRES_HOST=$POSTGRES_HOST|" "$ENV_FILE"
        sed_inline "s|POSTGRES_PORT=.*|POSTGRES_PORT=$POSTGRES_PORT|" "$ENV_FILE"
    fi
    
    # Storage configuration
    if [[ "$USE_LOCAL_STORAGE" == true ]]; then
        # Local filesystem storage
        sed_inline "s|N8N_DEFAULT_BINARY_DATA_MODE=.*|N8N_DEFAULT_BINARY_DATA_MODE=default|" "$ENV_FILE"
        # Comment out S3 variables since they're not used
        sed_inline "s|^S3_ENDPOINT_URL=|#S3_ENDPOINT_URL=|" "$ENV_FILE"
        sed_inline "s|^S3_BUCKET=|#S3_BUCKET=|" "$ENV_FILE"
        sed_inline "s|^S3_ACCESS_KEY_ID=|#S3_ACCESS_KEY_ID=|" "$ENV_FILE"
        sed_inline "s|^S3_SECRET_ACCESS_KEY=|#S3_SECRET_ACCESS_KEY=|" "$ENV_FILE"
        sed_inline "s|^S3_FORCE_PATH_STYLE=|#S3_FORCE_PATH_STYLE=|" "$ENV_FILE"
    else
        # S3 storage
        sed_inline "s|N8N_DEFAULT_BINARY_DATA_MODE=.*|N8N_DEFAULT_BINARY_DATA_MODE=s3|" "$ENV_FILE"
        sed_inline "s|#S3_ENDPOINT_URL=.*|S3_ENDPOINT_URL=$S3_ENDPOINT_URL|" "$ENV_FILE"
        sed_inline "s|#S3_BUCKET=.*|S3_BUCKET=$S3_BUCKET|" "$ENV_FILE"
        sed_inline "s|#S3_ACCESS_KEY_ID=.*|S3_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID|" "$ENV_FILE"
        sed_inline "s|#S3_SECRET_ACCESS_KEY=.*|S3_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY|" "$ENV_FILE"
        sed_inline "s|#S3_FORCE_PATH_STYLE=.*|S3_FORCE_PATH_STYLE=$S3_FORCE_PATH_STYLE|" "$ENV_FILE"
        sed_inline "s|S3_ENDPOINT_URL=.*|S3_ENDPOINT_URL=$S3_ENDPOINT_URL|" "$ENV_FILE"
        sed_inline "s|S3_BUCKET=.*|S3_BUCKET=$S3_BUCKET|" "$ENV_FILE"
        sed_inline "s|S3_ACCESS_KEY_ID=.*|S3_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID|" "$ENV_FILE"
        sed_inline "s|S3_SECRET_ACCESS_KEY=.*|S3_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY|" "$ENV_FILE"
        sed_inline "s|S3_FORCE_PATH_STYLE=.*|S3_FORCE_PATH_STYLE=$S3_FORCE_PATH_STYLE|" "$ENV_FILE"
    fi
    
    # Traefik
    sed_inline "s|TRAEFIK_ACME_EMAIL=.*|TRAEFIK_ACME_EMAIL=$TRAEFIK_ACME_EMAIL|" "$ENV_FILE"
    
    # Optional
    sed_inline "s|GENERIC_TIMEZONE=.*|GENERIC_TIMEZONE=$GENERIC_TIMEZONE|" "$ENV_FILE"
    
    # SMTP configuration
    if [[ "$CONFIGURE_SMTP" == true ]]; then
        sed_inline "s|#.*N8N_EMAIL_MODE=.*|N8N_EMAIL_MODE=$N8N_EMAIL_MODE|" "$ENV_FILE"
        sed_inline "s|#.*N8N_SMTP_HOST=.*|N8N_SMTP_HOST=$N8N_SMTP_HOST|" "$ENV_FILE"
        sed_inline "s|#.*N8N_SMTP_PORT=.*|N8N_SMTP_PORT=$N8N_SMTP_PORT|" "$ENV_FILE"
        sed_inline "s|#.*N8N_SMTP_USER=.*|N8N_SMTP_USER=$N8N_SMTP_USER|" "$ENV_FILE"
        sed_inline "s|#.*N8N_SMTP_PASS=.*|N8N_SMTP_PASS=$N8N_SMTP_PASS|" "$ENV_FILE"
        sed_inline "s|#.*N8N_SMTP_SENDER=.*|N8N_SMTP_SENDER=$N8N_SMTP_SENDER|" "$ENV_FILE"
        sed_inline "s|#.*N8N_SMTP_SSL=.*|N8N_SMTP_SSL=$N8N_SMTP_SSL|" "$ENV_FILE"
    fi
    
    # Secure the file
    chmod 600 "$ENV_FILE"
    
    print_success ".env file created and secured (chmod 600)"
}

# ============================================================================
# Systemd Service Setup
# ============================================================================

setup_systemd() {
    print_header "Setting Up Auto-Start on Boot"
    
    if prompt_yes_no "Enable auto-start on system boot (systemd)?" "y"; then
        print_info "Installing systemd service..."
        
        # Create systemd service
        cat > /etc/systemd/system/n8n-compose.service <<EOF
[Unit]
Description=n8n Docker Compose Stack
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_ROOT
ExecStart=/usr/bin/docker compose -f compose.yaml $([ "$USE_EXTERNAL_DB" == false ] && echo "-f compose.local-db.yaml") up -d
ExecStop=/usr/bin/docker compose down
ExecReload=/usr/bin/docker compose -f compose.yaml $([ "$USE_EXTERNAL_DB" == false ] && echo "-f compose.local-db.yaml") restart

TimeoutStartSec=300
TimeoutStopSec=60
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
        
        # Reload systemd
        systemctl daemon-reload
        systemctl enable n8n-compose.service
        
        print_success "Systemd service installed and enabled"
    fi
}

# ============================================================================
# Initial Deployment
# ============================================================================

initial_deployment() {
    print_header "Starting n8n Deployment"
    
    cd "$PROJECT_ROOT"
    
    print_info "Pulling Docker images..."
    if [[ "$USE_EXTERNAL_DB" == false ]]; then
        docker compose -f compose.yaml -f compose.local-db.yaml pull
    else
        docker compose pull
    fi
    
    print_info "Starting services..."
    if [[ "$USE_EXTERNAL_DB" == false ]]; then
        docker compose -f compose.yaml -f compose.local-db.yaml up -d
    else
        docker compose up -d
    fi
    
    print_success "Services started successfully!"
    
    if [[ "$USE_EXTERNAL_DB" == false ]]; then
        print_warning "Note: Local PostgreSQL may take 30 seconds to initialize on first start."
    fi
}

# ============================================================================
# Summary & Next Steps
# ============================================================================

print_summary() {
    print_header "Installation Complete!"
    
    echo ""
    print_success "n8n is now running!"
    echo ""
    print_info "Access your instance at: ${GREEN}https://${N8N_HOST}${NC}"
    echo ""
    print_warning "IMPORTANT: Save this information securely!"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Encryption Key (backup this!):${NC}"
    echo -e "${GREEN}$N8N_ENCRYPTION_KEY${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    print_info "Useful commands:"
    echo "  • View logs:           make logs"
    echo "  • Check status:        make status"
    echo "  • Upgrade:             make upgrade"
    echo "  • Create backup:       make backup"
    echo "  • Scale workers:       make scale-workers COUNT=3"
    echo ""
    
    print_info "Configuration file: $ENV_FILE"
    print_info "Created by: David Nagtzaam - https://davidnagtzaam.com"
    echo ""
}

install_man_pages() {
    print_header "Installing Documentation"
    
    print_info "Installing man pages for n8nctl..."
    
    if [ -f "$PROJECT_ROOT/man/man1/n8nctl.1" ]; then
        if mkdir -p /usr/local/share/man/man1 2>/dev/null && \
           cp "$PROJECT_ROOT/man/man1/n8nctl.1" /usr/local/share/man/man1/ 2>/dev/null && \
           chmod 644 /usr/local/share/man/man1/n8nctl.1 2>/dev/null; then
            
            # Update man database
            mandb 2>/dev/null || makewhatis 2>/dev/null || true
            
            print_success "Man pages installed successfully"
            print_info "View documentation with: man n8nctl"
        else
            print_warning "Could not install man pages (non-critical)"
        fi
    fi
    
    echo ""
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    clear
    
    print_header "n8n Production Deployment - Setup Wizard"
    echo ""
    print_info "Created by David Nagtzaam - https://davidnagtzaam.com"
    echo ""
    print_info "This wizard will help you configure and deploy n8n."
    print_info "Press Ctrl+C at any time to cancel."
    echo ""
    
    # Check if .env already exists
    if [[ -f "$ENV_FILE" ]]; then
        print_warning ".env file already exists!"
        if ! prompt_yes_no "Overwrite existing configuration?" "n"; then
            print_error "Installation cancelled"
            exit 1
        fi
    fi
    
    # Collect all configuration
    collect_domain_config
    collect_database_config
    collect_storage_config
    collect_encryption_key
    collect_optional_config
    
    # Create environment file
    create_env_file
    
    # Setup systemd
    setup_systemd
    
    # Deploy
    initial_deployment
    
    # Install man pages
    install_man_pages
    
    # Show summary
    print_summary
}

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root or with sudo"
    exit 1
fi

main "$@"
