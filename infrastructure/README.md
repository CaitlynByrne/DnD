# GameMaster's Companion - Infrastructure

This directory contains the complete Kubernetes infrastructure for GameMaster's Companion, optimized for local development with Kind and production deployment.

## Quick Start

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (running)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) v0.20+
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) v1.28+
- [Helm](https://helm.sh/docs/intro/install/) v3.12+

### 1. Setup Local Development Environment

#### Linux/Mac
```bash
# Make scripts executable
chmod +x infrastructure/scripts/*.sh

# Create and configure Kind cluster
./infrastructure/scripts/setup-kind-cluster.sh
```

#### Windows (PowerShell)
```powershell
# Create and configure Kind cluster
.\infrastructure\scripts\setup-kind-cluster.ps1
```

This will:
- Create a 3-node Kind cluster optimized for GameMaster's Companion
- Install required components (Ingress, storage, monitoring)
- Deploy the complete application stack
- Configure port forwarding for local access

### 2. Access Your Development Environment

After setup completes, services are available at:

- **Frontend**: http://localhost:3000
- **API**: http://localhost:8000
- **API Documentation**: http://localhost:8000/docs
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379
- **Elasticsearch**: http://localhost:9200
- **vLLM API**: http://localhost:8001
- **Grafana**: http://localhost:3000 (admin/admin)
- **Audio Processor**: http://localhost:8002

### 3. Development Workflow

#### Linux/Mac
```bash
# Check status of all services
./infrastructure/scripts/dev-workflow.sh status

# View logs
./infrastructure/scripts/dev-workflow.sh logs api
./infrastructure/scripts/dev-workflow.sh logs api follow

# Restart a service
./infrastructure/scripts/dev-workflow.sh restart api

# Update deployment after configuration changes
./infrastructure/scripts/dev-workflow.sh update

# Run database migrations
./infrastructure/scripts/dev-workflow.sh migrate

# Seed test data
./infrastructure/scripts/dev-workflow.sh seed

# Clean up everything
./infrastructure/scripts/dev-workflow.sh clean
```

#### Windows (PowerShell)
```powershell
# Check status of all services
.\infrastructure\scripts\dev-workflow.ps1 status

# View logs
.\infrastructure\scripts\dev-workflow.ps1 logs api
.\infrastructure\scripts\dev-workflow.ps1 logs api -Follow

# Restart a service
.\infrastructure\scripts\dev-workflow.ps1 restart api

# Update deployment after configuration changes
.\infrastructure\scripts\dev-workflow.ps1 update

# Run database migrations
.\infrastructure\scripts\dev-workflow.ps1 migrate

# Seed test data
.\infrastructure\scripts\dev-workflow.ps1 seed

# Clean up everything
.\infrastructure\scripts\dev-workflow.ps1 clean -Confirm
```

## Architecture Overview

### Services Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    Frontend     │    │       API       │    │   Audio Proc   │
│   (React/Next)  │◄──►│   (FastAPI)     │◄──►│   (Python)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌─────────────────┐              │
         │              │      vLLM       │              │
         │              │  (Local AI)     │              │
         │              └─────────────────┘              │
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
    │   PostgreSQL    │    │      Redis      │    │ Elasticsearch  │
    │   (Database)    │    │     (Cache)     │    │    (Search)     │
    └─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Kind Cluster Layout

- **Control Plane**: 1 node with ingress capabilities
- **Worker Nodes**: 2 nodes (one for standard workloads, one for AI)
- **Storage**: Local-path provisioner with persistent volumes
- **Networking**: Port forwarding for all services
- **Monitoring**: Prometheus + Grafana stack

## Configuration

### Environment-Specific Values

The Helm chart supports multiple environments through values files:

- `values.yaml` - Base configuration
- `values-development.yaml` - Local development overrides
- `values-production.yaml` - Production-ready configuration

### Key Configurations

#### Resource Allocation (Development)
```yaml
api:
  resources:
    requests: { memory: "128Mi", cpu: "50m" }
    limits: { memory: "256Mi", cpu: "100m" }

vllm:
  resources:
    requests: { memory: "1Gi", cpu: "500m" }
    limits: { memory: "2Gi", cpu: "1000m" }
```

#### Storage Strategy
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

## Advanced Usage

### Custom Configuration

1. **Modify values files** in `helm/gmc-dev/`
2. **Validate configuration**:
   ```bash
   # Linux/Mac
   python3 infrastructure/scripts/validate-config.py --environment development
   
   # Windows
   python infrastructure/scripts/validate-config.py --environment development
   ```
3. **Update deployment**:
   ```bash
   # Linux/Mac
   ./infrastructure/scripts/dev-workflow.sh update values-development.yaml
   
   # Windows (PowerShell)
   .\infrastructure\scripts\dev-workflow.ps1 update values-development.yaml
   ```

### Adding New Services

1. **Create deployment template** in `helm/gmc-dev/templates/`
2. **Add configuration** to values files
3. **Update _helpers.tpl** for new service URLs
4. **Validate and deploy**

### Debugging

```bash
# Check pod status
kubectl get pods -n gmc-dev

# Describe problematic pod
kubectl describe pod <pod-name> -n gmc-dev

# Check resource usage
kubectl top pods -n gmc-dev

# Access pod shell
kubectl exec -it deployment/gmc-dev-api -n gmc-dev -- /bin/bash

# Check cluster events
kubectl get events -n gmc-dev --sort-by='.lastTimestamp'
```

### Performance Tuning

#### For Development (Lower Resource Usage)
```yaml
# In values-development.yaml
ai:
  vllm:
    model: "microsoft/DialoGPT-small"  # Smaller model
    maxModelLen: 1024                  # Reduced context
    resources:
      limits: { memory: "1Gi" }        # Lower memory

monitoring:
  enabled: false  # Disable monitoring to save resources
```

#### For Production (High Performance)
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

## Troubleshooting

### Common Issues

#### 1. Cluster Won't Start
```bash
# Check Docker is running
docker info

# Recreate cluster - Linux/Mac
kind delete cluster --name gmc-dev
./infrastructure/scripts/setup-kind-cluster.sh

# Recreate cluster - Windows (PowerShell)
kind delete cluster --name gmc-dev
.\infrastructure\scripts\setup-kind-cluster.ps1
```

#### 2. Services Not Accessible
```bash
# Check port forwarding - Linux/Mac
./infrastructure/scripts/dev-workflow.sh port-forward all

# Check port forwarding - Windows (PowerShell)
.\infrastructure\scripts\dev-workflow.ps1 port-forward all

# Check ingress
kubectl get ingress -n gmc-dev
```

#### 3. Pods Stuck in Pending
```bash
# Check resource constraints
kubectl describe pod <pod-name> -n gmc-dev

# Check storage
kubectl get pv,pvc -n gmc-dev
```

#### 4. vLLM Out of Memory
```bash
# Reduce model size in values-development.yaml
ai:
  vllm:
    model: "microsoft/DialoGPT-small"
    maxModelLen: 512

# Update deployment - Linux/Mac
./infrastructure/scripts/dev-workflow.sh update

# Update deployment - Windows (PowerShell)
.\infrastructure\scripts\dev-workflow.ps1 update
```

### Resource Requirements

#### Minimum Development Setup
- **CPU**: 4 cores
- **Memory**: 8GB RAM
- **Storage**: 50GB available
- **Docker**: 4GB allocated to Docker

#### Recommended Development Setup
- **CPU**: 8 cores
- **Memory**: 16GB RAM
- **Storage**: 100GB available (SSD preferred)
- **Docker**: 8GB allocated to Docker

## Production Deployment

For production deployment on real Kubernetes clusters:

1. **Use production values**:
   ```bash
   helm install gmc infrastructure/helm/gmc-dev \
     --values infrastructure/helm/gmc-dev/values.yaml \
     --values infrastructure/helm/gmc-dev/values-production.yaml \
     --namespace gmc-production --create-namespace
   ```

2. **Configure external dependencies**:
   - External PostgreSQL cluster
   - Redis cluster or ElastiCache
   - Elasticsearch cluster
   - GPU nodes for vLLM
   - Load balancer for ingress

3. **Set up monitoring and alerting**:
   - Prometheus for metrics
   - Grafana for dashboards
   - AlertManager for notifications

## Security Considerations

### Development
- Default passwords are used for simplicity
- Network policies are disabled
- Debug endpoints are enabled
- External access is allowed for all services

### Production
- Use secure passwords and secrets management
- Enable network policies
- Disable debug endpoints
- Configure TLS certificates
- Set up proper RBAC

## Contributing

1. **Test changes locally** with development environment
2. **Validate configuration** with validation script
3. **Update documentation** for new features
4. **Test production values** in staging environment

## File Structure

```
infrastructure/
├── README.md                          # This file
├── kind-cluster-config.yaml          # Kind cluster configuration
├── storage-classes.yaml              # Storage configuration
├── helm/gmc-dev/                      # Helm chart
│   ├── Chart.yaml                     # Chart metadata
│   ├── values.yaml                    # Default values
│   ├── values-development.yaml        # Development overrides
│   ├── values-production.yaml         # Production configuration
│   └── templates/                     # Kubernetes templates
│       ├── _helpers.tpl               # Template helpers
│       ├── deployment.yaml            # Service deployments
│       ├── service.yaml               # Service definitions
│       ├── configmap.yaml             # Configuration maps
│       ├── secret.yaml                # Secrets
│       ├── ingress.yaml               # Ingress configuration
│       ├── health-checks.yaml         # Health monitoring
│       └── persistentvolumeclaim.yaml # Storage claims
└── scripts/                           # Automation scripts
    ├── setup-kind-cluster.sh          # Initial setup (Linux/Mac)
    ├── setup-kind-cluster.ps1         # Initial setup (Windows)
    ├── dev-workflow.sh                # Development commands (Linux/Mac)
    ├── dev-workflow.ps1               # Development commands (Windows)
    └── validate-config.py             # Configuration validation
```