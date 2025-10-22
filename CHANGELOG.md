# Changelog

All notable changes to n8nctl will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-17

### Initial Release

Complete n8n deployment and management tool.

#### Core Features

**Deployment & Setup**

- Interactive setup wizard
- Pre-flight validation checks
- Environment configuration validation
- Automated testing suite

**Operations & Maintenance**

- Comprehensive backup system
- Backup verification capability
- Smart retention management (configurable local backup limits)
- Disk space monitoring and warnings
- Full restore functionality
- Safe migration process
- Service upgrade management
- Health check monitoring
- Centralized log management

**Storage Options**

- Local filesystem storage (default)
- S3-compatible storage support (optional)
- Flexible configuration for different deployment sizes

**User Interface**

- Professional CLI tool
- Consistent UI library with symbol support
- Graceful fallbacks for non-TTY environments
- Optional gum integration for enhanced UI

**Architecture Support**

- Docker Compose orchestration
- Queue mode with scalable workers
- Traefik reverse proxy with automatic HTTPS
- Redis for distributed task queue
- PostgreSQL database (local or external)

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
**License**: MIT  
**Website**: https://davidnagtzaam.com
