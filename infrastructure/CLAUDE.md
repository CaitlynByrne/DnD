# Infrastructure - CLAUDE.md

This file provides infrastructure-specific guidance for GameMaster's Companion deployment and operations.

## Overview

GMC uses Kubernetes-native deployment with a complete local development environment using Kind. The infrastructure is designed for easy self-hosting while maintaining production-grade capabilities.

## Development Environment

### Setup Commands
```bash
# Initial cluster setup
./infrastructure/scripts/setup-kind-cluster.sh

# Development workflow management
./infrastructure/scripts/dev-workflow.sh <command>
```

### Core Development Workflow

**Service Management:**
```bash
# Check status of all services
./infrastructure/scripts/dev-workflow.sh status

# View logs (add 'follow' to tail logs)
./infrastructure/scripts/dev-workflow.sh logs api
./infrastructure/scripts/dev-workflow.sh logs api follow

# Restart a service
./infrastructure/scripts/dev-workflow.sh restart api

# Update deployment after configuration changes
./infrastructure/scripts/dev-workflow.sh update
```

**Database Operations:**
```bash
# Run database migrations
./infrastructure/scripts/dev-workflow.sh migrate

# Seed test data
./infrastructure/scripts/dev-workflow.sh seed
```

**Local Access:**
```bash
# Forward all services for local access
./infrastructure/scripts/dev-workflow.sh port-forward all

# Forward specific service
./infrastructure/scripts/dev-workflow.sh port-forward api
```

**Environment Cleanup:**
```bash
# Clean up everything (requires confirmation)
./infrastructure/scripts/dev-workflow.sh clean
```

## Configuration Management

### Helm Values Files
- `helm/gmc-dev/values.yaml` - Base configuration
- `helm/gmc-dev/values-development.yaml` - Development overrides  
- `helm/gmc-dev/values-production.yaml` - Production configuration

### Key Configuration Areas

**Resource Allocation (Development):**
```yaml
api:
  resources:
    requests: { memory: "256Mi", cpu: "100m" }
    limits: { memory: "512Mi", cpu: "250m" }

ai:
  vllm:
    resources:
      requests: { memory: "2Gi", cpu: "1000m" }
      limits: { memory: "4Gi", cpu: "2000m" }
```

**Storage Configuration:**
```yaml
postgresql:
  primary:
    persistence:
      size: 10Gi
      storageClass: "local-fast"

ai:
  vllm:
    persistence:
      size: 20Gi  # For model caching
      storageClass: "local-bulk"
```

### Environment Variables
Key environment variables managed through Helm:
- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_URL`: Redis connection string
- `ELASTICSEARCH_URL`: Search service endpoint
- `VLLM_API_URL`: AI service endpoint
- `AI_ENABLED`: Toggle AI features (true/false)
- `DEBUG`: Enable debug mode (true/false)

## Service Architecture

### Deployed Services
1. **gmc-dev-api**: FastAPI backend service
2. **gmc-dev-frontend**: React web application
3. **gmc-dev-vllm**: Local LLM deployment for AI features
4. **gmc-dev-audio-processor**: Real-time speech processing
5. **gmc-dev-postgresql**: Primary database
6. **gmc-dev-redis**: Caching and real-time features
7. **gmc-dev-elasticsearch**: Full-text search engine
8. **gmc-dev-grafana**: Monitoring dashboard

### Service Endpoints
- **Frontend**: http://localhost:3000
- **API**: http://localhost:8000
- **API Documentation**: http://localhost:8000/docs
- **PostgreSQL**: localhost:5432 (postgres/changeme)
- **Redis**: localhost:6379
- **Elasticsearch**: http://localhost:9200
- **vLLM API**: http://localhost:8001
- **Audio Processor**: http://localhost:8002
- **Grafana**: http://localhost:3000 (admin/admin)

## Debugging and Troubleshooting

### Kubernetes Debugging
```bash
# Check pod status
kubectl get pods -n gmc-dev

# Describe problematic pod
kubectl describe pod <pod-name> -n gmc-dev

# Check resource usage
kubectl top pods -n gmc-dev

# Access pod shell for debugging
kubectl exec -it deployment/gmc-dev-api -n gmc-dev -- /bin/bash

# Check cluster events
kubectl get events -n gmc-dev --sort-by='.lastTimestamp'
```

### Common Issues

**Cluster Won't Start:**
```bash
# Check Docker is running
docker info

# Recreate cluster
kind delete cluster --name gmc-dev
./infrastructure/scripts/setup-kind-cluster.sh
```

**Services Not Accessible:**
```bash
# Check port forwarding
./infrastructure/scripts/dev-workflow.sh port-forward all

# Check ingress configuration
kubectl get ingress -n gmc-dev
```

**Pods Stuck in Pending:**
```bash
# Check resource constraints
kubectl describe pod <pod-name> -n gmc-dev

# Check storage availability
kubectl get pv,pvc -n gmc-dev
```

**vLLM Out of Memory:**
```bash
# Reduce model size in values-development.yaml
ai:
  vllm:
    model: "microsoft/DialoGPT-small"
    maxModelLen: 512

# Update deployment
./infrastructure/scripts/dev-workflow.sh update
```

### Performance Tuning

**Development (Lower Resources):**
```yaml
# In values-development.yaml
ai:
  vllm:
    model: "microsoft/DialoGPT-small"
    maxModelLen: 1024
    resources:
      limits: { memory: "1Gi" }

monitoring:
  enabled: false  # Disable to save resources
```

**Production (High Performance):**
```yaml
# In values-production.yaml
api:
  replicaCount: 3
  resources:
    requests: { memory: "512Mi", cpu: "250m" }
    limits: { memory: "1Gi", cpu: "500m" }

ai:
  vllm:
    model: "microsoft/DialoGPT-large"
    replicaCount: 2
    nodeSelector:
      accelerator: "nvidia-tesla-v100"
```

## Configuration Validation

### Validation Commands
```bash
# Validate configuration before deployment
python3 infrastructure/scripts/validate-config.py --environment development

# Test Helm chart rendering
helm template gmc-dev infrastructure/helm/gmc-dev \
  --values infrastructure/helm/gmc-dev/values.yaml \
  --values infrastructure/helm/gmc-dev/values-development.yaml
```

## Database Operations

### Direct Database Access
```bash
# PostgreSQL access
kubectl exec -it deployment/gmc-dev-postgresql -n gmc-dev -- psql -U postgres -d gamemaster_companion

# Redis access
kubectl exec -it deployment/gmc-dev-redis-master -n gmc-dev -- redis-cli
```

### Backup and Restore
```bash
# Database backup (development)
kubectl exec deployment/gmc-dev-postgresql -n gmc-dev -- pg_dump -U postgres gamemaster_companion > backup.sql

# Database restore (development)
kubectl exec -i deployment/gmc-dev-postgresql -n gmc-dev -- psql -U postgres gamemaster_companion < backup.sql
```

## Security Considerations

### Development Environment
- Default passwords used for simplicity
- Network policies disabled for easier development
- Debug endpoints enabled
- All services externally accessible via port forwarding

### Production Deployment
- Secure password management required
- Network policies should be enabled
- Debug endpoints must be disabled
- TLS certificate configuration needed
- Proper RBAC implementation required

## Resource Requirements

### Minimum Development Setup
- **CPU**: 4 cores
- **Memory**: 8GB RAM
- **Storage**: 50GB available
- **Docker**: 4GB allocated to Docker

### Recommended Development Setup
- **CPU**: 8 cores
- **Memory**: 16GB RAM
- **Storage**: 100GB SSD
- **Docker**: 8GB allocated to Docker

### Production Considerations
- AI services require significant memory (2-4GB for vLLM)
- Audio processing is CPU-intensive
- Consider GPU acceleration for production AI workloads
- SSD storage recommended for database performance