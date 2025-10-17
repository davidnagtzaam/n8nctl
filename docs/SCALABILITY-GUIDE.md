# n8nctl Scalability Guide

## Full Vertical & Horizontal Scaling with External Redis and Supabase

This guide covers how to configure n8nctl for production-grade scalability using external managed services.

---

## 🎯 Overview

For production deployments requiring high availability and scalability, n8nctl supports:

- **Horizontal Scaling**: Multiple n8n workers processing workflows in parallel
- **Vertical Scaling**: Increased resources per container
- **External Database**: Supabase PostgreSQL for managed, scalable database
- **External Redis**: Managed Redis for reliable queue management
- **S3 Storage**: Object storage for binary data

---

## 📊 Architecture for Scale

```
                        ┌─────────────────────────┐
                        │    Load Balancer       │
                        │     (Traefik)          │
                        └───────────┬─────────────┘
                                    │
                ┌───────────────────┴───────────────────┐
                │                                       │
        ┌───────▼────────┐                    ┌────────▼───────┐
        │   n8n-web      │                    │   n8n-web      │
        │  (Primary)     │                    │  (Secondary)   │
        └────────────────┘                    └────────────────┘
                │                                       │
                └───────────────┬───────────────────────┘
                                │
        ┌───────────────────────┴───────────────────────┐
        │              Redis Cluster                    │
        │         (ElastiCache/Redis Cloud)             │
        └───────────────────────┬───────────────────────┘
                                │
    ┌───────────────────────────┴───────────────────────────┐
    │                                                       │
┌───▼─────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───▼─────┐
│Worker #1│  │Worker #2 │  │Worker #3 │  │Worker #4 │  │Worker #N│
└─────────┘  └──────────┘  └──────────┘  └──────────┘  └─────────┘
    │             │             │             │             │
    └─────────────┴─────────────┴─────────────┴─────────────┘
                                │
                    ┌───────────▼──────────┐
                    │    Supabase DB       │
                    │   (PostgreSQL)       │
                    └──────────────────────┘
```

---

## 🚀 Quick Setup for Scalability

### 1. Prerequisites

- **Supabase Account**: [supabase.com](https://supabase.com)
- **Redis Cloud Account**: [redis.com](https://redis.com) or AWS ElastiCache
- **S3-Compatible Storage**: Backblaze B2, AWS S3, or similar
- **Domain with DNS control**
- **Docker Swarm or Kubernetes** (for multi-node scaling)

### 2. Create External Services

#### Supabase PostgreSQL

1. Create new Supabase project
2. Go to Settings → Database
3. Copy the connection string (URI format)
4. Note: Use connection pooler URL for better performance

```bash
# Example Supabase connection string
postgresql://postgres.[PROJECT-REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres
```

#### Redis Cloud

1. Create Redis database
2. Enable Redis persistence
3. Copy connection details
4. Configure maxmemory policy: `allkeys-lru`

```bash
# Example Redis connection
redis://default:[PASSWORD]@[HOST]:[PORT]
```

---

## 📋 Configuration Steps

### 1. Initial Setup with External Services

Run the interactive setup wizard:

```bash
sudo ./scripts/init.sh
```

When prompted:

1. **Database Configuration**:
   - Select "External PostgreSQL"
   - Enter your Supabase connection string
   
2. **Storage Configuration**:
   - Select "S3-compatible storage"
   - Configure your S3 credentials

### 2. Configure External Redis

Edit your `.env` file after initial setup:

```bash
# External Redis Configuration
REDIS_URL=redis://default:your-password@redis-12345.c1.us-east-1-2.ec2.cloud.redislabs.com:12345

# Queue Configuration for External Redis
QUEUE_BULL_REDIS_HOST=
QUEUE_BULL_REDIS_PORT=
QUEUE_BULL_REDIS_URL=redis://default:your-password@redis-12345.c1.us-east-1-2.ec2.cloud.redislabs.com:12345

# Connection Pool Settings
QUEUE_BULL_REDIS_POOL_MIN=2
QUEUE_BULL_REDIS_POOL_MAX=50
QUEUE_HEALTH_CHECK_ACTIVE=true
```

### 3. Update Docker Compose

Create `compose.scale.yaml` for scaled deployment:

```yaml
version: '3.8'

services:
  n8n-web:
    environment:
      - REDIS_URL=${REDIS_URL}
      - DATABASE_URL=${DATABASE_URL}
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G

  n8n-worker:
    environment:
      - REDIS_URL=${REDIS_URL}
      - DATABASE_URL=${DATABASE_URL}
    deploy:
      replicas: 10
      resources:
        limits:
          cpus: '1'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 1G

  # Remove local redis and postgres services
  redis:
    deploy:
      replicas: 0

  postgres:
    deploy:
      replicas: 0
```

---

## 🎛️ Scaling Configurations

### Vertical Scaling (Single Node)

Increase resources per container:

```bash
# Update docker-compose.yaml
services:
  n8n-web:
    mem_limit: 8g
    cpus: 4
    
  n8n-worker:
    mem_limit: 4g
    cpus: 2
```

### Horizontal Scaling (Multiple Workers)

```bash
# Scale to 20 workers
n8nctl scale 20

# Or using docker-compose directly
docker compose up -d --scale n8n-worker=20
```

### Multi-Node Deployment

For true horizontal scaling across multiple servers:

1. **Docker Swarm Setup**:
```bash
# Initialize swarm on manager node
docker swarm init

# Join worker nodes
docker swarm join --token SWMTKN-1-xxx manager-ip:2377

# Deploy stack
docker stack deploy -c compose.scale.yaml n8n
```

2. **Kubernetes Deployment**:
```yaml
# n8n-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: n8n-worker
spec:
  replicas: 20
  selector:
    matchLabels:
      app: n8n-worker
  template:
    metadata:
      labels:
        app: n8n-worker
    spec:
      containers:
      - name: n8n
        image: n8nio/n8n:latest
        command: ["n8n", "worker"]
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: n8n-secrets
              key: database-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: n8n-secrets
              key: redis-url
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1"
```

---

## 🔧 Optimization Settings

### Database Connection Pooling

```bash
# Supabase connection pooling
DATABASE_URL=postgresql://postgres.[ref]:[pass]@[host]:6543/postgres?pgbouncer=true

# Connection pool settings
DB_POSTGRESDB_POOL_MIN=5
DB_POSTGRESDB_POOL_MAX=100
```

### Redis Optimization

```bash
# Redis settings for high throughput
QUEUE_BULL_REDIS_POOL_MAX=100
QUEUE_BULL_REDIS_CONNECTION_TIMEOUT=10000
QUEUE_BULL_REDIS_COMMAND_TIMEOUT=5000
QUEUE_BULL_REDIS_KEEP_ALIVE=30000
```

### Worker Concurrency

```bash
# Adjust based on workflow complexity
WORKER_CONCURRENCY=10  # Light workflows
WORKER_CONCURRENCY=5   # Heavy workflows
WORKER_CONCURRENCY=1   # Very heavy/long-running workflows
```

---

## 📊 Monitoring for Scale

### Key Metrics to Monitor

1. **Database Metrics** (Supabase Dashboard):
   - Connection count
   - Query performance
   - Storage usage
   - Replication lag

2. **Redis Metrics** (Redis Cloud Dashboard):
   - Memory usage
   - Commands/sec
   - Queue length
   - Eviction rate

3. **Container Metrics**:
```bash
# Monitor resource usage
docker stats

# Check worker distribution
docker service ps n8n_worker

# View queue status
docker exec -it n8n-web n8n queue:status
```

### Alerting Setup

```yaml
# prometheus-rules.yaml
groups:
  - name: n8n
    rules:
      - alert: HighQueueDepth
        expr: n8n_queue_jobs_waiting > 1000
        for: 5m
        
      - alert: WorkerMemoryHigh
        expr: container_memory_usage_bytes{name=~"n8n-worker.*"} > 1.5e+9
        for: 10m
```

---

## 🚨 Troubleshooting Scale Issues

### Common Issues

1. **Database Connection Exhaustion**
```bash
# Symptoms: "too many connections" errors
# Solution: Use connection pooling
DATABASE_URL=postgresql://...?pgbouncer=true&pool_timeout=60
```

2. **Redis Memory Full**
```bash
# Symptoms: Queue processing stops
# Solution: Increase Redis memory or adjust eviction policy
maxmemory-policy allkeys-lru
```

3. **Uneven Worker Load**
```bash
# Symptoms: Some workers idle while others overloaded
# Solution: Adjust queue settings
QUEUE_BULL_REDIS_CLUSTER_MODE=true
```

---

## 💰 Cost Optimization

### Supabase
- Start with Free tier (500MB database)
- Pro plan ($25/month) for 8GB database
- Scale vertically before adding read replicas

### Redis Cloud
- Free tier: 30MB (development only)
- Essentials: $7/month for 250MB
- Use connection pooling to minimize connections

### Compute Resources
- Use spot instances for workers
- Scale down during off-hours
- Right-size worker resources based on workflow needs

---

## 📚 Best Practices

1. **Database**:
   - Enable connection pooling
   - Use read replicas for analytics
   - Regular VACUUM and ANALYZE

2. **Redis**:
   - Enable persistence (RDB+AOF)
   - Set appropriate maxmemory
   - Monitor slow commands

3. **Workers**:
   - Group similar workflows
   - Set appropriate concurrency
   - Monitor memory usage

4. **Monitoring**:
   - Set up alerts for all components
   - Track workflow execution times
   - Monitor error rates

---

## 🔗 Additional Resources

- [Supabase Connection Pooling](https://supabase.com/docs/guides/database/connecting-to-postgres#connection-pooling)
- [Redis Best Practices](https://redis.io/docs/management/optimization/)
- [n8n Queue Mode](https://docs.n8n.io/hosting/configuration/queue-mode/)
- [Docker Swarm Guide](https://docs.docker.com/engine/swarm/)

---

**Created by**: David Nagtzaam  
**Project**: n8nctl  
**Version**: 1.0.0
