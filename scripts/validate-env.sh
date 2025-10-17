#!/usr/bin/env bash
# =============================================================================
# n8n Production Deployment - Environment Validation Script
# =============================================================================
# Description: Validates .env file for required variables and correct formats
# Author: David Nagtzaam
# Version: 1.0.0
# =============================================================================

set -euo pipefail

# Load shared UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/lib-ui.sh"

# Variables
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"
ERRORS=0
WARNINGS=0

# =============================================================================
# Validation Functions
# =============================================================================

check_file_exists() {
    print_header "Checking .env File"
    
    if [ ! -f "$ENV_FILE" ]; then
        print_error ".env file not found at: $ENV_FILE"
        echo ""
        print_info "Create it by running: sudo ./scripts/init.sh"
        exit 1
    fi
    
    print_success ".env file found"
}

check_file_permissions() {
    print_header "Checking File Permissions"
    
    local perms=$(stat -c %a "$ENV_FILE" 2>/dev/null || stat -f %A "$ENV_FILE" 2>/dev/null)
    
    if [ "$perms" != "600" ]; then
        print_warn "Insecure permissions: $perms (should be 600)"
        echo "  ${SYMBOL_ARROW} Fix with: chmod 600 $ENV_FILE"
        ((WARNINGS++))
    else
        print_success "Permissions are secure (600)"
    fi
}

validate_required_vars() {
    print_header "Validating Required Variables"
    
    source "$ENV_FILE"
    
    # Core required variables
    local required=(
        "N8N_HOST:Domain where n8n will be accessible"
        "N8N_PROTOCOL:Protocol (should be https in production)"
        "WEBHOOK_URL:Full webhook URL"
        "N8N_ENCRYPTION_KEY:Encryption key for credentials"
        "POSTGRES_PASSWORD:PostgreSQL password"
    )
    
    for entry in "${required[@]}"; do
        local var="${entry%%:*}"
        local desc="${entry#*:}"
        
        if [ -z "${!var:-}" ]; then
            print_error "$var is not set"
            echo "  ${SYMBOL_INFO} $desc"
            ((ERRORS++))
        else
            print_success "$var is set"
        fi
    done
}

validate_placeholder_values() {
    print_header "Checking for Placeholder Values"
    
    # Common placeholder patterns
    local placeholders=(
        "change_me"
        "your_"
        "example.com"
        "placeholder"
        "not_used"
        "CHANGE"
    )
    
    local found=false
    
    for placeholder in "${placeholders[@]}"; do
        local matches=$(grep -v "^#" "$ENV_FILE" | grep -i "$placeholder" || true)
        
        if [ -n "$matches" ]; then
            found=true
            print_warn "Found placeholder pattern: '$placeholder'"
            echo "$matches" | while read line; do
                echo "  ${SYMBOL_ARROW} $line"
            done
            ((WARNINGS++))
        fi
    done
    
    if [ "$found" = false ]; then
        print_success "No placeholder values detected"
    fi
}

validate_encryption_key() {
    print_header "Validating Encryption Key"
    
    source "$ENV_FILE"
    
    if [ -z "${N8N_ENCRYPTION_KEY:-}" ]; then
        print_error "N8N_ENCRYPTION_KEY is not set"
        ((ERRORS++))
        return
    fi
    
    local key_length=${#N8N_ENCRYPTION_KEY}
    
    if [ $key_length -lt 24 ]; then
        print_error "Encryption key too short ($key_length chars, minimum 24)"
        ((ERRORS++))
    elif [ $key_length -lt 32 ]; then
        print_warn "Encryption key could be stronger ($key_length chars, recommended 32+)"
        ((WARNINGS++))
    else
        print_success "Encryption key is strong ($key_length chars)"
    fi
}

validate_database_config() {
    print_header "Validating Database Configuration"
    
    source "$ENV_FILE"
    
    if [ -n "${DATABASE_URL:-}" ]; then
        # External database
        print_success "Using external PostgreSQL"
        
        # Validate DATABASE_URL format
        if [[ "$DATABASE_URL" =~ ^postgresql:// ]]; then
            print_success "DATABASE_URL format is correct"
        else
            print_error "DATABASE_URL format invalid (should start with postgresql://)"
            ((ERRORS++))
        fi
    else
        # Local database
        print_success "Using local PostgreSQL"
        
        if [ -z "${POSTGRES_PASSWORD:-}" ]; then
            print_error "POSTGRES_PASSWORD not set"
            ((ERRORS++))
        elif [ "${POSTGRES_PASSWORD}" = "change_me_to_strong_password" ]; then
            print_error "POSTGRES_PASSWORD is still default value"
            ((ERRORS++))
        else
            print_success "POSTGRES_PASSWORD is set"
        fi
    fi
}

validate_storage_config() {
    print_header "Validating Storage Configuration"
    
    source "$ENV_FILE"
    
    local mode="${N8N_DEFAULT_BINARY_DATA_MODE:-default}"
    
    if [ "$mode" = "default" ]; then
        print_success "Using local filesystem storage"
    elif [ "$mode" = "s3" ]; then
        print_success "Using S3-compatible storage"
        
        # Validate S3 variables
        local s3_vars=(
            "S3_BUCKET"
            "S3_ACCESS_KEY_ID"
            "S3_SECRET_ACCESS_KEY"
        )
        
        for var in "${s3_vars[@]}"; do
            if [ -z "${!var:-}" ]; then
                print_error "$var not set (required for S3 mode)"
                ((ERRORS++))
            fi
        done
    else
        print_error "Unknown storage mode: $mode (should be 'default' or 's3')"
        ((ERRORS++))
    fi
}

validate_protocol() {
    print_header "Validating Protocol Configuration"
    
    source "$ENV_FILE"
    
    if [ "${N8N_PROTOCOL:-}" = "https" ]; then
        print_success "Using HTTPS (recommended for production)"
    elif [ "${N8N_PROTOCOL:-}" = "http" ]; then
        print_warn "Using HTTP (not recommended for production)"
        echo "  ${SYMBOL_INFO} Switch to HTTPS in production environments"
        ((WARNINGS++))
    else
        print_error "N8N_PROTOCOL invalid or not set"
        ((ERRORS++))
    fi
}

validate_domain() {
    print_header "Validating Domain Configuration"
    
    source "$ENV_FILE"
    
    if [ -z "${N8N_HOST:-}" ]; then
        print_error "N8N_HOST not set"
        ((ERRORS++))
        return
    fi
    
    # Check if domain contains protocol (common mistake)
    if [[ "$N8N_HOST" =~ ^https?:// ]]; then
        print_error "N8N_HOST should not include protocol (remove http:// or https://)"
        ((ERRORS++))
    elif [[ "$N8N_HOST" = "localhost" ]] || [[ "$N8N_HOST" =~ ^127\. ]] || [[ "$N8N_HOST" =~ ^192\.168\. ]]; then
        print_warn "Using local/private domain (not suitable for production)"
        ((WARNINGS++))
    elif [[ "$N8N_HOST" = *"example.com"* ]]; then
        print_error "Domain is still example.com placeholder"
        ((ERRORS++))
    else
        print_success "Domain format looks correct: $N8N_HOST"
    fi
}

validate_smtp_config() {
    print_header "Validating SMTP Configuration (Optional)"
    
    source "$ENV_FILE"
    
    if [ -n "${N8N_EMAIL_MODE:-}" ] && [ "${N8N_EMAIL_MODE}" = "smtp" ]; then
        print_info "SMTP is configured"
        
        local smtp_vars=(
            "N8N_SMTP_HOST"
            "N8N_SMTP_PORT"
            "N8N_SMTP_USER"
            "N8N_SMTP_PASS"
        )
        
        for var in "${smtp_vars[@]}"; do
            if [ -z "${!var:-}" ]; then
                print_warn "$var not set (SMTP may not work)"
                ((WARNINGS++))
            fi
        done
    else
        print_info "SMTP not configured (optional)"
    fi
}

validate_traefik_email() {
    print_header "Validating Traefik Configuration"
    
    source "$ENV_FILE"
    
    if [ -z "${TRAEFIK_ACME_EMAIL:-}" ]; then
        print_error "TRAEFIK_ACME_EMAIL not set (required for Let's Encrypt)"
        ((ERRORS++))
    elif [[ "${TRAEFIK_ACME_EMAIL}" = *"example.com"* ]]; then
        print_error "TRAEFIK_ACME_EMAIL is still placeholder"
        ((ERRORS++))
    elif [[ "${TRAEFIK_ACME_EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        print_success "TRAEFIK_ACME_EMAIL format is valid"
    else
        print_warn "TRAEFIK_ACME_EMAIL format may be invalid"
        ((WARNINGS++))
    fi
}

check_syntax_errors() {
    print_header "Checking for Syntax Errors"
    
    # Try to source the file in a subshell
    if bash -c "source '$ENV_FILE'" 2>/dev/null; then
        print_success "No syntax errors detected"
    else
        print_error "Syntax errors found in .env file"
        echo "  ${SYMBOL_INFO} Common issues:"
        echo "  ${SYMBOL_ARROW} Unquoted values with special characters"
        echo "  ${SYMBOL_ARROW} Missing = signs"
        echo "  ${SYMBOL_ARROW} Invalid variable names"
        ((ERRORS++))
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

show_summary() {
    echo ""
    print_header "Validation Summary"
    
    echo ""
    if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
        print_success "Environment configuration is valid!"
        echo ""
        print_info "Ready to proceed with deployment"
        return 0
    elif [ $ERRORS -eq 0 ]; then
        print_warn "Validation passed with $WARNINGS warning(s)"
        echo ""
        print_info "Review warnings above, but you can proceed"
        return 0
    else
        print_error "Validation failed with $ERRORS error(s) and $WARNINGS warning(s)"
        echo ""
        print_info "Fix errors before proceeding with deployment"
        return 1
    fi
}

main() {
    clear
    print_banner "n8n Environment Validator" "Version 1.0.0"
    
    echo ""
    check_file_exists
    echo ""
    check_file_permissions
    echo ""
    validate_required_vars
    echo ""
    validate_placeholder_values
    echo ""
    validate_encryption_key
    echo ""
    validate_database_config
    echo ""
    validate_storage_config
    echo ""
    validate_protocol
    echo ""
    validate_domain
    echo ""
    validate_traefik_email
    echo ""
    validate_smtp_config
    echo ""
    check_syntax_errors
    echo ""
    
    show_summary
}

main "$@"
