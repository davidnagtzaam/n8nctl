# n8nctl - n8n Control Tool

Complete command-line interface for managing your n8n deployment.

## 📋 Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Commands Reference](#commands-reference)
- [Common Workflows](#common-workflows)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)

## Overview

`n8nctl` is a convenient CLI wrapper that simplifies common n8n operations. Instead of remembering complex Docker Compose commands, use simple, intuitive commands to manage your deployment.

### What Does It Do?

- ✅ Manage service lifecycle (start, stop, restart)
- ✅ Monitor logs and service status
- ✅ Create and restore backups
- ✅ Upgrade to latest versions
- ✅ Scale workers dynamically
- ✅ Run health checks
- ✅ Execute commands in containers
- ✅ Quick access to container shells

## Installation

`n8nctl` is automatically installed with the n8nctl project.

### Make It Globally Available (Optional)

```bash
# Create symlink in /usr/local/bin
sudo ln -s /opt/n8nctl/scripts/n8nctl /usr/local/bin/n8nctl

# Now run from anywhere
n8nctl status
```

## Quick Start

```bash
# Check if services are running
n8nctl status

# View logs
n8nctl logs

# Restart all services
n8nctl restart

# Create a backup
n8nctl backup

# Run health checks
n8nctl health
```

## Commands Reference

### Service Management

#### `n8nctl status`
Display current status of all services.

```bash
n8nctl status
```

**Output**: Shows running containers, their status, and ports.

---

#### `n8nctl start`
Start all n8n services.

```bash
n8nctl start
```

**What it does**:
- Starts n8n-web (main application)
- Starts n8n-worker (background job processor)
- Starts PostgreSQL (if using local database)
- Starts Traefik (reverse proxy)

**Notes**: Automatically detects if you're using local or external database.

---

#### `n8nctl stop`
Stop all n8n services.

```bash
n8nctl stop
```

**What it does**: Gracefully stops all containers without removing data.

**Use case**: Maintenance, freeing resources, or before server restart.

---

#### `n8nctl restart`
Restart all services.

```bash
n8nctl restart
```

**When to use**:
- After configuration changes
- When services become unresponsive
- To apply new environment variables

---

### Logs & Monitoring

#### `n8nctl logs [service]`
View container logs in real-time.

```bash
# View logs from all services
n8nctl logs

# View logs from specific service
n8nctl logs n8n-web
n8nctl logs n8n-worker
n8nctl logs postgres
n8nctl logs traefik
```

**Options**:
- Shows last 100 lines by default
- Follows logs in real-time (Ctrl+C to exit)
- Color-coded output for easy reading

**Use cases**:
- Debugging errors
- Monitoring workflow executions
- Checking startup issues
- Investigating performance problems

---

### Backup & Restore

#### `n8nctl backup`
Create a complete backup of your n8n instance.

```bash
n8nctl backup
```

**What it backs up**:
- ✅ Complete PostgreSQL database
- ✅ All configuration files (.env)
- ✅ Docker volumes
- ✅ Metadata (version, timestamp)

**Output location**: `/tmp/n8n-backup-YYYYMMDD-HHMMSS.tgz`

**Includes**:
- All workflows
- All credentials (encrypted)
- Execution history
- User accounts
- Settings

**Best practice**: Run before upgrades or major changes.

---

#### `n8nctl restore <backup-file>`
Restore from a backup file.

```bash
n8nctl restore /tmp/n8n-backup-20251017-143022.tgz
```

**⚠️ WARNING**: This will **replace all current data**!

**What it does**:
1. Validates backup file
2. Stops all services
3. Restores database
4. Restores configuration
5. Restarts services
6. Verifies health

**Safety tip**: Always create a backup before restoring!

---

### Upgrades & Maintenance

#### `n8nctl upgrade`
Upgrade n8n to the latest version.

```bash
n8nctl upgrade
```

**What it does**:
1. Creates automatic backup
2. Pulls latest Docker images
3. Stops services
4. Upgrades containers
5. Runs database migrations
6. Starts services
7. Verifies health

**Safety features**:
- Automatic backup before upgrade
- Rollback option if upgrade fails
- Version verification

**Recommended**: Always upgrade during low-traffic periods.

---

#### `n8nctl health`
Run comprehensive health checks.

```bash
n8nctl health
```

**Checks**:
- ✅ Service status
- ✅ Database connectivity
- ✅ Disk space
- ✅ Memory usage
- ✅ Network connectivity
- ✅ SSL certificates
- ✅ Backup status

**Use cases**:
- Pre-deployment verification
- Troubleshooting issues
- Regular maintenance checks
- Monitoring automation

---

### Scaling

#### `n8nctl scale <count>`
Scale the number of worker containers.

```bash
# Scale to 3 workers
n8nctl scale 3

# Scale to 1 worker (reduce)
n8nctl scale 1

# Scale to 10 workers (heavy load)
n8nctl scale 10
```

**What are workers?**
- Background processes that execute workflows
- More workers = more parallel workflow executions
- Each worker consumes ~200-500MB RAM

**When to scale up**:
- High workflow volume
- Many concurrent executions
- Complex, long-running workflows

**When to scale down**:
- Low usage periods
- Resource constraints
- Cost optimization

**Recommendation**:
- Start with 2-3 workers
- Monitor execution queue
- Scale based on actual usage

---

### Container Access

#### `n8nctl version`
Display current n8n version.

```bash
n8nctl version
```

**Output**: Shows the running n8n version number.

---

#### `n8nctl shell [service]`
Open an interactive shell in a container.

```bash
# Shell in main app (default)
n8nctl shell

# Shell in specific service
n8nctl shell n8n-web
n8nctl shell n8n-worker
n8nctl shell postgres
```

**Use cases**:
- Debugging container issues
- Inspecting files
- Manual database queries
- Testing configurations

**Exit shell**: Type `exit` or press Ctrl+D

---

#### `n8nctl exec <service> <command>`
Execute a single command in a container.

```bash
# Check n8n version
n8nctl exec n8n-web n8n --version

# List files
n8nctl exec n8n-web ls -la /data

# Database query
n8nctl exec postgres psql -U n8n -c "SELECT COUNT(*) FROM workflow"

# Check environment variables
n8nctl exec n8n-web env | grep N8N_
```

**Use cases**:
- Quick checks without opening shell
- Automation scripts
- Monitoring commands
- One-off administrative tasks

---

### Help

#### `n8nctl help`
Display help information.

```bash
n8nctl help
n8nctl --help
n8nctl -h
```

## Common Workflows

### Daily Operations

#### Check System Health
```bash
# Morning routine
n8nctl status        # Are services running?
n8nctl health        # Any issues?
n8nctl logs | tail   # Recent activity
```

#### Monitor Running Workflows
```bash
# Watch logs in real-time
n8nctl logs n8n-web

# In another terminal, check worker logs
n8nctl logs n8n-worker
```

---

### Maintenance Tasks

#### Weekly Backup
```bash
# Create backup
n8nctl backup

# Copy to external storage
sudo cp /tmp/n8n-backup-*.tgz /mnt/backups/
```

#### Monthly Upgrade
```bash
# 1. Check current status
n8nctl health

# 2. Upgrade
n8nctl upgrade

# 3. Verify
n8nctl status
n8nctl version
n8nctl health
```

---

### Troubleshooting

#### Services Won't Start
```bash
# Check status
n8nctl status

# View logs for errors
n8nctl logs

# Try restart
n8nctl restart

# If still failing, check detailed logs
n8nctl logs n8n-web
n8nctl logs postgres
```

#### High Load / Slow Workflows
```bash
# Scale up workers
n8nctl scale 5

# Monitor logs
n8nctl logs n8n-worker

# Check system health
n8nctl health
```

#### Database Issues
```bash
# Access database shell
n8nctl shell postgres

# Inside: Run queries
psql -U n8n
\dt  # List tables
SELECT COUNT(*) FROM workflow;
```

#### Configuration Changes Not Applied
```bash
# After editing .env file
n8nctl restart

# Verify environment
n8nctl exec n8n-web env | grep N8N_
```

---

### Disaster Recovery

#### Complete System Restore
```bash
# 1. Stop services
n8nctl stop

# 2. Restore from backup
n8nctl restore /path/to/backup.tgz

# 3. Verify
n8nctl status
n8nctl health
n8nctl version
```

#### Rollback After Failed Upgrade
```bash
# n8nctl upgrade creates automatic backup
# Find the pre-upgrade backup
ls -lt /tmp/n8n-backup-*

# Restore it
n8nctl restore /tmp/n8n-backup-20251017-120000.tgz
```

---

### Performance Optimization

#### Monitor Resource Usage
```bash
# Check container stats
docker stats

# Check logs for slow queries
n8nctl logs | grep "slow"

# Check disk space
df -h
```

#### Optimize Worker Count
```bash
# Start with 2 workers
n8nctl scale 2

# Monitor execution queue
n8nctl logs n8n-worker | grep "Executing workflow"

# Scale based on load:
# - Low load: 1-2 workers
# - Medium load: 3-5 workers
# - High load: 5-10 workers
```

---

## Troubleshooting

### Command Not Found

**Problem**: `bash: n8nctl: command not found`

**Solution**:
```bash
# Run with full path
/opt/n8nctl/scripts/n8nctl status

# Or create alias
echo 'alias n8nctl="/opt/n8nctl/scripts/n8nctl"' >> ~/.bashrc
source ~/.bashrc

# Or symlink to system path
sudo ln -s /opt/n8nctl/scripts/n8nctl /usr/local/bin/n8nctl
```

---

### Permission Denied

**Problem**: `Permission denied` when running commands

**Solution**:
```bash
# n8nctl needs sudo for Docker commands
sudo n8nctl status

# Or add user to docker group
sudo usermod -aG docker $USER
# Log out and back in for changes to take effect
```

---

### Services Won't Stop

**Problem**: `n8nctl stop` hangs or fails

**Solution**:
```bash
# Force stop
sudo docker compose -f /opt/n8nctl/compose.yaml down -t 30

# If still hanging, force kill
sudo docker compose -f /opt/n8nctl/compose.yaml kill
```

---

### Backup Fails

**Problem**: Backup creation fails

**Solutions**:
```bash
# Check disk space
df -h /tmp

# Check permissions
ls -la /tmp

# Check if database is accessible
n8nctl exec postgres pg_isready

# Try manual backup
sudo docker compose exec postgres pg_dump -U n8n n8n > /tmp/manual-backup.sql
```

---

## Advanced Usage

### Automation Examples

#### Automated Daily Backups
```bash
# Add to crontab
sudo crontab -e

# Add line:
0 2 * * * /opt/n8nctl/scripts/n8nctl backup && cp /tmp/n8n-backup-*.tgz /mnt/backups/
```

#### Health Check Monitoring
```bash
# Check health every 5 minutes, alert on failure
*/5 * * * * /opt/n8nctl/scripts/n8nctl health || /usr/bin/send-alert.sh
```

#### Auto-scaling Based on Time
```bash
# Scale up during business hours
0 8 * * 1-5 /opt/n8nctl/scripts/n8nctl scale 5

# Scale down at night
0 18 * * 1-5 /opt/n8nctl/scripts/n8nctl scale 2
```

---

### Integration with Monitoring

#### Prometheus Metrics
```bash
# Expose Docker metrics
n8nctl exec n8n-web wget -qO- http://localhost:5678/metrics
```

#### Log Aggregation
```bash
# Stream logs to file
n8nctl logs > /var/log/n8n/app.log 2>&1 &

# Stream to syslog
n8nctl logs | logger -t n8n
```

---

### Custom Wrapper Scripts

#### Weekly Maintenance Script
```bash
#!/usr/bin/env bash
# weekly-maintenance.sh

echo "Starting weekly n8n maintenance..."

# Health check
n8nctl health

# Create backup
n8nctl backup

# Upgrade if available
n8nctl upgrade

# Final health check
n8nctl health

echo "Maintenance complete!"
```

#### Quick Status Dashboard
```bash
#!/usr/bin/env bash
# status-dashboard.sh

clear
echo "╔════════════════════════════════════════╗"
echo "║     n8n Deployment Status              ║"
echo "╚════════════════════════════════════════╝"
echo ""
n8nctl status
echo ""
echo "─────────────────────────────────────────"
echo "Version:"
n8nctl version
echo ""
echo "─────────────────────────────────────────"
echo "Recent Activity:"
n8nctl logs | tail -n 10
```

---

## Command Cheat Sheet

| Command | What It Does | Example |
|---------|-------------|---------|
| `status` | Show service status | `n8nctl status` |
| `start` | Start all services | `n8nctl start` |
| `stop` | Stop all services | `n8nctl stop` |
| `restart` | Restart services | `n8nctl restart` |
| `logs` | View logs | `n8nctl logs n8n-web` |
| `backup` | Create backup | `n8nctl backup` |
| `restore` | Restore backup | `n8nctl restore backup.tgz` |
| `upgrade` | Upgrade n8n | `n8nctl upgrade` |
| `scale` | Scale workers | `n8nctl scale 5` |
| `health` | Run health checks | `n8nctl health` |
| `version` | Show version | `n8nctl version` |
| `shell` | Open container shell | `n8nctl shell` |
| `exec` | Execute command | `n8nctl exec n8n-web ls` |
| `help` | Show help | `n8nctl help` |

---

## Tips & Best Practices

1. **Always backup before upgrades**
   ```bash
   n8nctl backup && n8nctl upgrade
   ```

2. **Monitor logs during critical operations**
   ```bash
   # Terminal 1
   n8nctl logs -f
   
   # Terminal 2
   n8nctl upgrade
   ```

3. **Use health checks in automation**
   ```bash
   if n8nctl health; then
       echo "All systems operational"
   else
       echo "Issues detected, alerting admin..."
   fi
   ```

4. **Regular maintenance schedule**
   - Daily: Check status and logs
   - Weekly: Create backup
   - Monthly: Run full health check and upgrade

5. **Scale proactively**
   - Monitor workflow execution times
   - Scale up before expected high load
   - Scale down during quiet periods to save resources

---

## Support

- **Documentation**: See `/README.md` in project root
- **Examples**: See `/examples/` directory
- **Framework**: See `/lib/README.md` for UI framework details
- **Issues**: Create ticket at project repository

---

**Version**: 1.0  
**Last Updated**: October 17, 2025  
**Part of**: n8nctl by David Nagtzaam  
**Website**: https://davidnagtzaam.com
