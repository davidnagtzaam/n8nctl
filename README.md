# n8nctl - Professional n8n Deployment Tool

**Version 1.0.0** | Production Ready

A comprehensive tool for deploying and managing n8n self-hosted in production environments.

---

## ✨ Features

### Deployment & Setup

- 🎯 Interactive setup wizard
- ✓ Pre-flight validation
- ✓ Environment configuration validation
- ✓ Automated testing suite

### Operations & Maintenance

- 💾 Comprehensive backup system with verification
- ♻️ Full restore functionality
- 🔄 Safe migration process
- ⬆️ Service upgrade management
- 🏥 Health check monitoring
- 📋 Centralized log management

### Storage Flexibility

- 📁 Local filesystem storage (simple)
- ☁️ S3-compatible storage (scalable)
- ⚙️ Flexible configuration options

### Architecture

- 🐳 Docker Compose orchestration
- 👷 Queue mode with scalable workers
- 🔒 Traefik reverse proxy with automatic HTTPS
- 🔴 Redis for distributed task queue
- 🐘 PostgreSQL database (local or external)

---

## 🚀 Quick Start

### Prerequisites

- Docker 20.10+ with Compose V2
- Ubuntu 20.04+ / Debian 11+ (or compatible)
- 2GB+ RAM, 10GB+ disk space
- Domain with DNS configured
- Root or sudo access

### Installation

#### Step 1: Download and Extract

```bash
# Download the latest release
wget https://github.com/davidnagtzaam/n8nctl/releases/latest/download/n8nctl.tar.gz

# Extract the archive
tar -xzf n8nctl.tar.gz
cd n8nctl
```

#### Step 2: Install n8nctl

```bash
# Install to /opt/n8nctl (requires sudo)
sudo bash install.sh
```

This will:

- Install n8nctl to `/opt/n8nctl`
- Create system-wide `n8nctl` command
- Install man pages
- Set proper permissions

#### Step 3: Check Requirements

```bash
# Run pre-flight checks
sudo n8nctl preflight
```

#### Step 4: Configure and Deploy

```bash
# Interactive setup wizard
sudo n8nctl init
```

That's it! Your n8n instance will be running with automatic HTTPS.

### Uninstallation

```bash
# Remove n8nctl (preserves data)
sudo n8nctl uninstall

# Remove n8nctl and all data
sudo n8nctl uninstall --remove-data

# Remove n8nctl, data, and configuration
sudo n8nctl uninstall --remove-data --remove-config
```

---

## 📖 Usage

The `n8nctl` command is your complete interface for all operations:

```bash
# Setup & Installation
sudo n8nctl init           # Interactive setup wizard
sudo n8nctl preflight      # Check system requirements

# Service Management
n8nctl start               # Start all services
n8nctl stop                # Stop all services
n8nctl restart             # Restart services
n8nctl status              # Show service status
n8nctl scale 5             # Scale workers to 5

# Logs & Monitoring
n8nctl logs tail           # Follow all logs
n8nctl logs tail n8n-web   # Follow specific service
n8nctl logs show -n 500    # Show last 500 lines
n8nctl logs search "error" # Search for errors
n8nctl logs errors         # Show only errors
n8nctl logs export         # Export logs to file
n8nctl logs list           # List available services
n8nctl health              # Run health checks

# Operations
n8nctl backup              # Create backup
n8nctl restore <file>      # Restore from backup
sudo n8nctl migrate        # Safe version migration
sudo n8nctl upgrade        # Upgrade to latest

# Utilities
n8nctl test                # Run deployment tests
n8nctl validate            # Validate configuration
n8nctl version             # Show n8n version
n8nctl shell <service>     # Open shell in container
n8nctl exec <svc> <cmd>    # Execute command in container
n8nctl help                # Show all commands
```

---

## 📚 Detailed Documentation

### Deployment

1. **Pre-Flight Checks**

   ```bash
   sudo n8nctl preflight
   ```

   Validates system requirements before deployment.

2. **Interactive Setup**

   ```bash
   sudo n8nctl init
   ```

   Guides you through:
   - Domain configuration
   - Database setup (local or external)
   - Storage configuration (local or S3)
   - SMTP settings (optional)
   - Encryption key generation

3. **Validation**

   ```bash
   n8nctl validate
   ```

   Validates `.env` configuration for errors and placeholders.

4. **Testing**
   ```bash
   n8nctl test
   ```
   Runs comprehensive tests on your deployment.

### Backup & Restore

**Create Backup:**

```bash
n8nctl backup
```

Creates backup including:

- PostgreSQL database
- n8n workflows and credentials
- Configuration files
- Metadata with timestamp

**Restore from Backup:**

```bash
n8nctl restore /tmp/n8n-backup-<timestamp>.tgz
```

Restores complete system state from backup.

**Backup Configuration:**

Edit `.env` to configure retention:

```bash
# Keep 7 most recent local backups
BACKUP_RETENTION_LOCAL=7

# Backup destination
BACKUP_DESTINATION=/tmp
```

### Migration & Upgrades

**Safe Migration:**

```bash
sudo n8nctl migrate
```

Performs safe version upgrade with:

- Automatic pre-migration backup
- Image pull and update
- Database migration (automatic)
- Verification
- Rollback capability if issues occur

**Quick Upgrade:**

```bash
sudo n8nctl upgrade
```

Quick upgrade without full migration process.

### Log Management

```bash
# View all logs in real-time
n8nctl logs tail

# View specific service
n8nctl logs tail n8n-web

# Show recent logs
n8nctl logs show -n 500

# Search logs
n8nctl logs search "error"

# Show only errors
n8nctl logs errors

# Export logs
n8nctl logs export

# List services
n8nctl logs list
```

### Health Monitoring

```bash
n8nctl health
```

Performs comprehensive health checks:

- Service status
- API responsiveness
- Database connectivity
- Queue health
- Disk space
- Memory usage

---

## ⚙️ Configuration

### Storage Options

**Local Filesystem** (default):

```bash
N8N_DEFAULT_BINARY_DATA_MODE=default
```

**S3-Compatible Storage** (recommended for production):

```bash
N8N_DEFAULT_BINARY_DATA_MODE=s3
S3_ENDPOINT_URL=https://s3.us-west-002.backblazeb2.com
S3_BUCKET=n8n-binaries
S3_ACCESS_KEY_ID=your_key
S3_SECRET_ACCESS_KEY=your_secret
S3_FORCE_PATH_STYLE=true
```

### Database Options

**Local PostgreSQL:**

```bash
POSTGRES_USER=n8n
POSTGRES_PASSWORD=strong_password
POSTGRES_DB=n8n
```

**External PostgreSQL:**

```bash
DATABASE_URL=postgresql://user:pass@host:5432/n8n
```

### Backup Configuration

```bash
# Local backup retention (number of backups)
BACKUP_RETENTION_LOCAL=7

# Remote backup retention (days, for S3)
BACKUP_RETENTION_DAYS=30

# Backup schedule (cron format)
BACKUP_SCHEDULE=0 2 * * *
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Internet                           │
│                          ↓                              │
│                    ┌──────────┐                         │
│                    │ Traefik  │ (Port 80/443)           │
│                    │  Proxy   │ (Auto HTTPS)            │
│                    └──────────┘                         │
│                          ↓                              │
│              ┌───────────┴───────────┐                  │
│              ↓                       ↓                  │
│         ┌─────────┐           ┌──────────┐              │
│         │ n8n-web │           │ n8n-     │              │
│         │         │           │ worker   │ (Scalable)   │
│         └─────────┘           └──────────┘              │
│              ↓                       ↓                  │
│         ┌────────────────────────────┘                  │
│         ↓                  ↓                            │
│    ┌─────────┐      ┌────────────┐                      │
│    │  Redis  │      │ PostgreSQL │                      │
│    │  Queue  │      │  Database  │                      │
│    └─────────┘      └────────────┘                      │
│                                                         │
│    Storage: Local filesystem OR S3-compatible           │
└─────────────────────────────────────────────────────────┘
```

---

## 🧪 Testing

Run the comprehensive test suite:

```bash
n8nctl test
```

Tests include:

- Environment configuration
- Docker availability
- Service health
- Database connectivity
- Redis connectivity
- n8n API responsiveness
- Traefik routing
- SSL configuration
- Storage configuration

---

## 🛠️ Troubleshooting

### Services Won't Start

```bash
# Check service status
n8nctl status

# View logs
n8nctl logs

# Check specific service
n8nctl logs n8n-web

# Run health check
n8nctl health
```

### Configuration Issues

```bash
# Validate environment
n8nctl validate

# Check for placeholders
grep -i "change_me\|your_\|example.com" .env
```

### Database Connection Issues

```bash
# Check database logs
n8nctl logs tail postgres

# Test database connectivity
n8nctl test
```

### Backup/Restore Issues

```bash
# Verify backup integrity
tar tzf /tmp/n8n-backup-<timestamp>.tgz

# Check backup contents
tar -tzf /tmp/n8n-backup-<timestamp>.tgz | less
```

---

## 📊 Requirements

| Component | Minimum      | Recommended   |
| --------- | ------------ | ------------- |
| CPU       | 1 core       | 2+ cores      |
| RAM       | 2GB          | 4GB+          |
| Disk      | 10GB         | 20GB+         |
| Docker    | 20.10+       | Latest        |
| OS        | Ubuntu 20.04 | Ubuntu 22.04+ |

---

## 🔒 Security

- Automatic HTTPS via Let's Encrypt
- Secure file permissions (600 for .env)
- Encryption key management
- Security headers via Traefik
- Rate limiting
- No new privileges for containers

---

## 📝 File Structure

```
n8nctl/
├── scripts/             # All operational scripts
│   ├── init.sh          # Setup wizard
│   ├── test.sh          # Test suite
│   ├── validate-env.sh  # Config validation
│   ├── migrate.sh       # Safe migration
│   ├── backup.sh        # Backup system
│   ├── restore.sh       # Restore system
│   ├── upgrade.sh       # Upgrade management
│   ├── healthcheck.sh   # Health monitoring
│   ├── logs.sh          # Log management
│   ├── preflight.sh     # Pre-flight checks
│   └── n8nctl           # Main CLI
├── lib/                 # Shared libraries
│   └── lib-ui.sh        # UI components
├── compose.yaml         # Docker Compose config
├── compose.local-db.yaml # Local PostgreSQL config
├── env.template         # Configuration template
├── README.md            # This file
├── CHANGELOG.md         # Version history
├── TODO.md              # Future enhancements
└── VERSION              # Version number
```

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Check TODO.md for planned features
2. Create an issue for discussion
3. Follow existing code style
4. Add tests for new features
5. Update documentation

---

## 📄 License

GNU General Public License 3.0 - See LICENSE file for details

---

## 👤 Author

**David Nagtzaam**  
Website: https://davidnagtzaam.com

---

## 🙏 Acknowledgments

- [n8n.io](https://n8n.io) - Workflow automation platform
- [Traefik](https://traefik.io) - Modern reverse proxy
- [Charm.sh](https://charm.sh) - Beautiful CLI tools

---

## 📞 Support

- Issues: Open an issue in the repository
- Documentation: Check docs/ folder
- Community: Join n8n community forums

---

**Version:** 1.0.0  
**Status:** Production Ready  
**Last Updated:** October 17, 2025
