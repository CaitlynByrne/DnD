# Infrastructure Technical PRD - GameMaster's Companion

## Overview

The infrastructure provides a scalable, self-hosted Kubernetes deployment that supports the GameMaster's Companion platform with high availability, security, and operational excellence while maintaining data sovereignty for privacy-conscious users.

## Architecture Philosophy

### Self-Hosted First
- **Complete Data Sovereignty:** All data remains within user's infrastructure
- **No External Dependencies:** Platform functions without internet connectivity
- **Privacy by Design:** No telemetry or data collection by default
- **Offline Capability:** Core features work during network outages

### Cloud-Native Principles
- **Containerized Services:** All components run in containers
- **Declarative Configuration:** Infrastructure as Code approach
- **Immutable Infrastructure:** Containers rebuilt rather than modified
- **Service Mesh:** Secure inter-service communication
- **Loosely Coupled Architecture:** Each containerized serivce is loosely coupled, using appropriate APIs, DNS lookups, and similar

## Kubernetes Deployment Architecture

### Cluster Requirements

#### Minimum Hardware Requirements
- **Control Plane:** 2 vCPU, 4GB RAM, 50GB storage
- **Worker Nodes:** 4 vCPU, 8GB RAM, 100GB storage per node
- **AI Processing Node:** 8 vCPU, 16GB RAM, 200GB storage (optional GPU support)
- **Recommended:** 3-node cluster for high availability
- **Storage:** networked storage (e.g., Ceph or MinIO) or local-path provisioner for persistent volumes
- **Concurrent Users:** Support 1-15 concurrent users per instance

#### Network Requirements
- **Pod Network:** Cilium CNI plugin
- **Service Mesh:** Istio for advanced networking
- **Load Balancer:** MetalLB for bare-metal deployments
- **Ingress:** NGINX Ingress Controller with TLS termination

### Namespace Organization
```yaml
# Namespace structure
namespaces:
  - gmc-app          # Application services
  - gmc-data         # Data services (postgres, redis, elasticsearch)
  - gmc-ai           # AI and ML services (vllm, diart)
  - gmc-monitoring   # Monitoring and observability
  - gmc-system       # System utilities and operators
  - gmc-integrations # External integrations (discord, dndbeyond)
```

### Service Deployment Manifests

#### Application Services
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gmc-api
  namespace: gmc-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: gmc-api
  template:
    metadata:
      labels:
        app: gmc-api
    spec:
      containers:
      - name: api
        image: gmc/api:latest
        ports:
        - containerPort: 8000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: gmc-secrets
              key: database-url
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
```

#### Data Services Configuration
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql
  namespace: gmc-data
spec:
  serviceName: postgresql
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
      - name: postgresql
        image: postgres:15-alpine
        env:
        - name: POSTGRES_DB
          value: gamemaster_companion
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 50Gi
```

## Storage Architecture

### Persistent Volume Strategy
- **Database Storage:** SSD-backed persistent volumes for PostgreSQL
- **File Storage:** Object storage (MinIO) for media files
- **Cache Storage:** Redis with persistent volumes for session data
- **Backup Storage:** Separate volume for automated backups

### Storage Classes
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/no-provisioner
parameters:
  type: local-ssd
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: backup-storage
provisioner: kubernetes.io/no-provisioner
parameters:
  type: network-attached
volumeBindingMode: Immediate
reclaimPolicy: Retain
```

### Backup Strategy
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: gmc-data
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: postgres-backup
            image: postgres:15-alpine
            command:
            - /bin/bash
            - -c
            - |
              pg_dump -h postgresql -U $POSTGRES_USER -d gamemaster_companion \
                | gzip > /backup/backup-$(date +%Y%m%d-%H%M%S).sql.gz
              find /backup -name "backup-*.sql.gz" -mtime +7 -delete
            env:
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: username
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: password
            volumeMounts:
            - name: backup-volume
              mountPath: /backup
          volumes:
          - name: backup-volume
            persistentVolumeClaim:
              claimName: backup-pvc
          restartPolicy: OnFailure
```

## AI and ML Infrastructure

### Local LLM Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-server
  namespace: gmc-ai
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vllm-server
  template:
    metadata:
      labels:
        app: vllm-server
    spec:
      containers:
      - name: vllm
        image: vllm/vllm-openai:latest
        ports:
        - containerPort: 8000
        env:
        - name: MODEL_NAME
          value: "microsoft/DialoGPT-medium"
        - name: GPU_MEMORY_UTILIZATION
          value: "0.9"
        - name: MAX_MODEL_LEN
          value: "4096"
        args:
        - --model
        - $(MODEL_NAME)
        - --host
        - 0.0.0.0
        - --port
        - "8000"
        - --gpu-memory-utilization
        - $(GPU_MEMORY_UTILIZATION)
        - --max-model-len
        - $(MAX_MODEL_LEN)
        resources:
          requests:
            memory: "4Gi"
            cpu: "2000m"
            nvidia.com/gpu: 1  # Optional GPU support
          limits:
            memory: "8Gi"
            cpu: "4000m"
            nvidia.com/gpu: 1
        volumeMounts:
        - name: vllm-models
          mountPath: /root/.cache/huggingface
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: vllm-models
        persistentVolumeClaim:
          claimName: vllm-models-pvc
      nodeSelector:
        accelerator: nvidia-tesla-k80  # Optional GPU node selection
```

### Audio Processing Service
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: audio-processor
  namespace: gmc-ai
spec:
  replicas: 2
  selector:
    matchLabels:
      app: audio-processor
  template:
    metadata:
      labels:
        app: audio-processor
    spec:
      containers:
      - name: audio-processor
        image: gmc/audio-processor:latest
        ports:
        - containerPort: 8001
        env:
        - name: DIART_MODEL
          value: "pyannote/segmentation-3.0"
        - name: DIART_STEP
          value: "0.5"
        - name: DIART_LATENCY
          value: "0.5"
        - name: REDIS_URL
          valueFrom:
            configMapKeyRef:
              name: gmc-config
              key: redis-url
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
        volumeMounts:
        - name: audio-models
          mountPath: /models
        livenessProbe:
          httpGet:
            path: /health
            port: 8001
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8001
          initialDelaySeconds: 10
          periodSeconds: 5
      volumes:
      - name: audio-models
        persistentVolumeClaim:
          claimName: audio-models-pvc
```

### Discord Integration Service
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: discord-integration
  namespace: gmc-integrations
spec:
  replicas: 1
  selector:
    matchLabels:
      app: discord-integration
  template:
    metadata:
      labels:
        app: discord-integration
    spec:
      containers:
      - name: discord-bot
        image: gmc/discord-integration:latest
        ports:
        - containerPort: 8002
        env:
        - name: DISCORD_BOT_TOKEN
          valueFrom:
            secretKeyRef:
              name: discord-secret
              key: bot-token
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: gmc-secrets
              key: database-url
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
```

### Elasticsearch Deployment
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
  namespace: gmc-data
spec:
  serviceName: elasticsearch
  replicas: 1
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:8.5.0
        ports:
        - containerPort: 9200
        - containerPort: 9300
        env:
        - name: discovery.type
          value: single-node
        - name: ES_JAVA_OPTS
          value: "-Xms1g -Xmx1g"
        - name: xpack.security.enabled
          value: "false"
        volumeMounts:
        - name: elasticsearch-storage
          mountPath: /usr/share/elasticsearch/data
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
  volumeClaimTemplates:
  - metadata:
      name: elasticsearch-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 20Gi
```

## Monitoring and Observability

### Prometheus Stack Deployment
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: gmc-monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    scrape_configs:
    - job_name: 'gmc-api'
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - gmc-app
      relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        action: keep
        regex: gmc-api
    
    - job_name: 'postgres-exporter'
      static_configs:
      - targets: ['postgres-exporter:9187']
    
    - job_name: 'redis-exporter'
      static_configs:
      - targets: ['redis-exporter:9121']
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: gmc-monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus
        - name: prometheus-storage
          mountPath: /prometheus
        command:
        - /bin/prometheus
        - --config.file=/etc/prometheus/prometheus.yml
        - --storage.tsdb.path=/prometheus
        - --web.console.libraries=/etc/prometheus/console_libraries
        - --web.console.templates=/etc/prometheus/consoles
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
      - name: prometheus-storage
        persistentVolumeClaim:
          claimName: prometheus-storage-pvc
```

### Grafana Dashboard Configuration
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards
  namespace: gmc-monitoring
data:
  gmc-overview.json: |
    {
      "dashboard": {
        "title": "GameMaster's Companion Overview",
        "panels": [
          {
            "title": "API Response Time",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
              }
            ]
          },
          {
            "title": "Active Sessions",
            "type": "stat",
            "targets": [
              {
                "expr": "gmc_active_sessions_total"
              }
            ]
          }
        ]
      }
    }
```

### Logging Infrastructure
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: gmc-monitoring
spec:
  selector:
    matchLabels:
      name: fluent-bit
  template:
    metadata:
      labels:
        name: fluent-bit
    spec:
      containers:
      - name: fluent-bit
        image: fluent/fluent-bit:latest
        env:
        - name: FLUENT_ELASTICSEARCH_HOST
          value: "elasticsearch"
        - name: FLUENT_ELASTICSEARCH_PORT
          value: "9200"
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: fluent-bit-config
          mountPath: /fluent-bit/etc/
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: fluent-bit-config
        configMap:
          name: fluent-bit-config
```

## Security Configuration

### Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: gmc-app-netpol
  namespace: gmc-app
spec:
  podSelector:
    matchLabels:
      tier: app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8000
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: gmc-data
    ports:
    - protocol: TCP
      port: 5432  # PostgreSQL
    - protocol: TCP
      port: 6379  # Redis
  - to:
    - namespaceSelector:
        matchLabels:
          name: gmc-ai
    ports:
    - protocol: TCP
      port: 8000  # vLLM
```

### TLS Configuration
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: gmc-tls
  namespace: gmc-app
spec:
  secretName: gmc-tls-secret
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  dnsNames:
  - gamemaster.local
  - api.gamemaster.local
```

### Secret Management
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: gmc-secrets
  namespace: gmc-app
type: Opaque
data:
  database-url: <base64-encoded-database-url>
  redis-url: <base64-encoded-redis-url>
  jwt-secret: <base64-encoded-jwt-secret>
  vllm-api-key: <base64-encoded-vllm-key>
---
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: gmc-app
spec:
  provider:
    vault:
      server: "https://vault.local"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "gmc-app"
```

## Deployment Automation

### Helm Chart Structure
```
gmc-helm-chart/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   └── statefulset.yaml
├── charts/
│   ├── postgresql/
│   ├── redis/
│   └── elasticsearch/
└── crds/
    └── gmc-crds.yaml
```

### Helm Values Configuration
```yaml
# values.yaml
global:
  imageRegistry: "registry.local"
  imagePullSecrets: []
  storageClass: "fast-ssd"

api:
  replicaCount: 3
  image:
    repository: gmc/api
    tag: "latest"
    pullPolicy: IfNotPresent
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"

postgresql:
  enabled: true
  auth:
    postgresPassword: "changeme"
    database: "gamemaster_companion"
  primary:
    persistence:
      enabled: true
      size: 50Gi
      storageClass: "fast-ssd"

redis:
  enabled: true
  auth:
    enabled: false
  master:
    persistence:
      enabled: true
      size: 10Gi

ai:
  vllm:
    enabled: true
    model: "microsoft/DialoGPT-medium"
    maxModelLen: 4096
    gpuMemoryUtilization: 0.9
    resources:
      requests:
        memory: "4Gi"
        cpu: "2000m"
      limits:
        memory: "8Gi"
        cpu: "4000m"
  
  diart:
    enabled: true
    model: "pyannote/segmentation-3.0"
    step: 0.5
    latency: 0.5
    realtime: true
    speakerDiarization: true

monitoring:
  prometheus:
    enabled: true
  grafana:
    enabled: true
    adminPassword: "admin"
  loki:
    enabled: true

integrations:
  discord:
    enabled: true
    botToken: "" # Configure via secret
    webhookSupport: true
  
  dndbeyond:
    enabled: true
    apiSupport: true
    characterImport: true

search:
  elasticsearch:
    enabled: true
    replicas: 1
    storage: "20Gi"
    fuzzySearch: true
    phoneticMatching: true
```

### GitOps Integration
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gmc-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://git.local/gmc/helm-charts
    targetRevision: main
    path: gmc-helm-chart
    helm:
      valueFiles:
      - values.yaml
      - values-production.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: gmc-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

## Operational Procedures

### Health Checks and Monitoring
```yaml
apiVersion: v1
kind: Service
metadata:
  name: health-check-service
  namespace: gmc-system
spec:
  selector:
    app: health-checker
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: health-checker
  namespace: gmc-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: health-checker
  template:
    metadata:
      labels:
        app: health-checker
    spec:
      containers:
      - name: health-checker
        image: gmc/health-checker:latest
        ports:
        - containerPort: 8080
        env:
        - name: CHECK_INTERVAL
          value: "30s"
        - name: SERVICES_TO_CHECK
          value: "gmc-api,postgresql,redis,vllm-server"
```

### Disaster Recovery
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: disaster-recovery
  namespace: gmc-system
spec:
  template:
    spec:
      containers:
      - name: recovery
        image: gmc/recovery-tools:latest
        command:
        - /bin/bash
        - -c
        - |
          # Restore PostgreSQL from backup
          gunzip -c /backup/latest-backup.sql.gz | \
            psql -h postgresql -U $POSTGRES_USER -d gamemaster_companion
          
          # Verify data integrity
          psql -h postgresql -U $POSTGRES_USER -d gamemaster_companion \
            -c "SELECT COUNT(*) FROM campaigns;"
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        volumeMounts:
        - name: backup-volume
          mountPath: /backup
      volumes:
      - name: backup-volume
        persistentVolumeClaim:
          claimName: backup-pvc
      restartPolicy: Never
```

### Scaling Procedures
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: gmc-api-hpa
  namespace: gmc-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: gmc-api
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
```

## Installation and Setup

### Quick Start Installation
```bash
#!/bin/bash
# install.sh - Quick installation script

set -e

echo "Installing GameMaster's Companion..."

# Check prerequisites
kubectl version --client
helm version

# Add Helm repositories
helm repo add gmc https://charts.gamemaster-companion.local
helm repo update

# Create namespace
kubectl create namespace gmc-app

# Install with default values
helm install gmc gmc/gamemaster-companion \
  --namespace gmc-app \
  --set postgresql.auth.postgresPassword="$(openssl rand -base64 32)" \
  --set global.domain="gamemaster.local" \
  --wait

echo "Installation complete!"
echo "Access the application at: https://gamemaster.local"
```

### Configuration Management
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: gmc-installer-config
  namespace: gmc-system
data:
  install.yaml: |
    installation:
      domain: "gamemaster.local"
      storage:
        class: "fast-ssd"
        size: "100Gi"
      ai:
        enabled: true
        gpu: false
      monitoring:
        enabled: true
      backup:
        enabled: true
        schedule: "0 2 * * *"
        retention: "7d"
```

This infrastructure design provides a complete, self-hosted solution that maintains data privacy while delivering enterprise-grade reliability and scalability for the GameMaster's Companion platform.