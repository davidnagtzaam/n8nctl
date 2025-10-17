# Changelog

All notable changes to n8nctl will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-17

### Initial Release

Complete n8n deployment and management tool with professional code quality.

#### Core Features

**Deployment & Setup**

- Interactive setup wizard (`init.sh`)
- Pre-flight validation checks (`preflight.sh`)
- Environment configuration validation (`validate-env.sh`)
- Automated testing suite (`test.sh`)

**Operations & Maintenance**

- Comprehensive backup system (`backup.sh`)
- Backup verification capability
- Smart retention management (configurable local backup limits)
- Disk space monitoring and warnings
- Full restore functionality (`restore.sh`)
- Safe migration process (`migrate.sh`)
- Service upgrade management (`upgrade.sh`)
- Health check monitoring (`healthcheck.sh`)
- Centralized log management (`logs.sh`)

**Storage Options**

- Local filesystem storage (default)
- S3-compatible storage support (optional)
- Flexible configuration for different deployment sizes

**User Interface**

- Professional CLI tool (`n8nctl`)
- Consistent UI library with symbol support (✓ ✗ ○ ● → ℹ ⚠)
- Graceful fallbacks for non-TTY environments
- Optional gum integration for enhanced UI

**Architecture Support**

- Docker Compose orchestration
- Queue mode with scalable workers
- Traefik reverse proxy with automatic HTTPS
- Redis for distributed task queue
- PostgreSQL database (local or external)

#### Technical Highlights

- **Code Quality**: Professional coding standards with comprehensive inline comments
- **Error Handling**: Robust error management with `set -euo pipefail`
- **Modularity**: Shared UI library following DRY principles
- **Security**: Secure file permissions, credential management
- **Testing**: Automated test suite covering all major components
- **Documentation**: Comprehensive guides and inline documentation

#### Files Included

**Core Scripts**

- `scripts/init.sh` - Interactive deployment wizard
- `scripts/test.sh` - Automated testing suite
- `scripts/validate-env.sh` - Environment validation
- `scripts/migrate.sh` - Safe migration process
- `scripts/backup.sh` - Backup with verification
- `scripts/restore.sh` - Restore from backup
- `scripts/upgrade.sh` - Version upgrades
- `scripts/healthcheck.sh` - Health monitoring
- `scripts/logs.sh` - Log management
- `scripts/preflight.sh` - Pre-deployment checks
- `scripts/n8nctl` - Main CLI interface

**Libraries**

- `lib/lib-ui.sh` - Shared UI components

**Configuration**

- `compose.yaml` - Main Docker Compose configuration
- `compose.local-db.yaml` - Optional local PostgreSQL
- `.env.template` - Environment configuration template

**Documentation**

- `README.md` - Complete setup and usage guide
- `TODO.md` - Future enhancement roadmap
- `CHANGELOG.md` - This file

#### Requirements

- Docker 20.10+ with Compose V2
- Ubuntu 20.04+ / Debian 11+ (or compatible Linux)
- 2GB+ RAM minimum
- 10GB+ disk space
- Domain with DNS configured
- Root or sudo access

---

## Future Versions

See `TODO.md` for planned enhancements and feature roadmap.

---

**Project**: n8nctl  
**Author**: David Nagtzaam  
**License**: MPL-2.0  
**Website**: https://davidnagtzaam.com
