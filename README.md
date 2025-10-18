# n8nctl - Professional n8n Deployment Tool

**Version 1.0.0** | Production Ready

A comprehensive, professional tool for deploying and managing n8n in production environments.

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

```bash
# Extract the archive
tar -xzf n8nctl-v1.0.0.tar.gz
cd n8nctl

# Make scripts executable
chmod +x scripts/*.sh scripts/n8nctl

# Run pre-flight checks
sudo ./scripts/preflight.sh

# Interactive setup
sudo ./scripts/init.sh
```

That's it! Your n8n instance will be running with automatic HTTPS.

---

## 📖 Usage

### Main CLI Tool

The `n8nctl` command provides quick access to all operations:

```bash
# Service management
n8nctl status              # Show service status
n8nctl start               # Start all services
n8nctl stop                # Stop all services
n8nctl restart             # Restart services

# Operations
n8nctl test                # Run deployment tests
n8nctl validate            # Validate configuration
n8nctl backup              # Create backup
n8nctl restore <file>      # Restore from backup
n8nctl migrate             # Safe version migration
n8nctl upgrade             # Upgrade to latest

# Monitoring
n8nctl health              # Run health checks
n8nctl logs [service]      # View logs
n8nctl version             # Show n8n version

# Scaling
n8nctl scale 5             # Scale workers to 5

# Help
n8nctl help                # Show all commands
```

### Individual Scripts

You can also run scripts directly:

```bash
# Deployment
sudo ./scripts/init.sh              # Interactive setup
sudo ./scripts/preflight.sh         # Pre-flight checks

# Validation & Testing
./scripts/validate-env.sh           # Validate configuration
./scripts/test.sh                   # Run test suite

# Operations
sudo ./scripts/backup.sh            # Create backup
sudo ./scripts/restore.sh <file>    # Restore backup
sudo ./scripts/migrate.sh           # Safe migration
sudo ./scripts/upgrade.sh           # Upgrade version

# Monitoring
./scripts/healthcheck.sh            # Health checks
./scripts/logs.sh [command]         # Log management
```

---

## 📚 Detailed Documentation

### Deployment

1. **Pre-Flight Checks**

   ```bash
   sudo ./scripts/preflight.sh
   ```

   Validates system requirements before deployment.

2. **Interactive Setup**

   ```bash
   sudo ./scripts/init.sh
   ```

   Guides you through:
   - Domain configuration
   - Database setup (local or external)
   - Storage configuration (local or S3)
   - SMTP settings (optional)
   - Encryption key generation

3. **Validation**

   ```bash
   ./scripts/validate-env.sh
   ```

   Validates `.env` configuration for errors and placeholders.

4. **Testing**
   ```bash
   ./scripts/test.sh
   ```
   Runs comprehensive tests on your deployment.

### Backup & Restore

**Create Backup:**

```bash
sudo ./scripts/backup.sh
```

Creates backup including:

- PostgreSQL database
- n8n workflows and credentials
- Configuration files
- Metadata with timestamp

**Restore from Backup:**

```bash
sudo ./scripts/restore.sh /tmp/n8n-backup-<timestamp>.tgz
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
sudo ./scripts/migrate.sh
```

Performs safe version upgrade with:

- Automatic pre-migration backup
- Image pull and update
- Database migration (automatic)
- Verification
- Rollback capability if issues occur

**Quick Upgrade:**

```bash
sudo ./scripts/upgrade.sh
```

Quick upgrade without full migration process.

### Log Management

```bash
# View all logs in real-time
./scripts/logs.sh tail

# View specific service
./scripts/logs.sh tail n8n-web

# Show recent logs
./scripts/logs.sh show -n 500

# Search logs
./scripts/logs.sh search "error"

# Show only errors
./scripts/logs.sh errors

# Export logs
./scripts/logs.sh export

# List services
./scripts/logs.sh list
```

### Health Monitoring

```bash
./scripts/healthcheck.sh
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
./scripts/test.sh
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
./scripts/validate-env.sh

# Check for placeholders
grep -i "change_me\|your_\|example.com" .env
```

### Database Connection Issues

```bash
# Check database logs
n8nctl logs postgres

# Test database connectivity
./scripts/test.sh
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
├── scripts/              # All operational scripts
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
├── .env.template        # Configuration template
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
