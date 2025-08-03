#!/bin/bash
# GameMaster's Companion Development Workflow Scripts
# Provides common development tasks for local Kind environment

set -euo pipefail

CLUSTER_NAME="gmc-dev"
NAMESPACE="gmc-dev"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to check if cluster is running
check_cluster() {
    if ! kind get clusters | grep -q "^$CLUSTER_NAME$"; then
        log_error "Kind cluster '$CLUSTER_NAME' not found. Run setup-kind-cluster.sh first."
        exit 1
    fi
    
    if ! kubectl cluster-info --context "kind-$CLUSTER_NAME" >/dev/null 2>&1; then
        log_error "Cannot connect to cluster '$CLUSTER_NAME'. Is it running?"
        exit 1
    fi
}

# Function to get pod status
get_pod_status() {
    local service=$1
    kubectl get pods -n $NAMESPACE -l "app.kubernetes.io/component=$service" \
        -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound"
}

# Function to wait for pod to be ready
wait_for_pod() {
    local service=$1
    local timeout=${2:-300}
    
    log_info "Waiting for $service to be ready..."
    kubectl wait --for=condition=Ready pod \
        -l "app.kubernetes.io/component=$service" \
        -n $NAMESPACE --timeout=${timeout}s
}

# Function to show cluster status
status() {
    log_info "GameMaster's Companion Development Environment Status"
    echo
    
    # Check cluster
    if kind get clusters | grep -q "^$CLUSTER_NAME$"; then
        echo "✅ Kind cluster '$CLUSTER_NAME' is running"
    else
        echo "❌ Kind cluster '$CLUSTER_NAME' not found"
        return 1
    fi
    
    # Check namespace
    if kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
        echo "✅ Namespace '$NAMESPACE' exists"
    else
        echo "❌ Namespace '$NAMESPACE' not found"
        return 1
    fi
    
    # Check services
    echo
    echo "Service Status:"
    services=("api" "frontend" "vllm" "audio-processor")
    for service in "${services[@]}"; do
        status=$(get_pod_status $service)
        case $status in
            "Running")
                echo "  ✅ $service: $status"
                ;;
            "Pending")
                echo "  🔄 $service: $status"
                ;;
            "NotFound")
                echo "  ❌ $service: Not deployed"
                ;;
            *)
                echo "  ⚠️  $service: $status"
                ;;
        esac
    done
    
    # Check databases
    echo
    echo "Data Services:"
    data_services=("postgresql" "redis" "elasticsearch")
    for service in "${data_services[@]}"; do
        if kubectl get pods -n $NAMESPACE -l "app.kubernetes.io/name=$service" >/dev/null 2>&1; then
            status=$(kubectl get pods -n $NAMESPACE -l "app.kubernetes.io/name=$service" \
                -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
            case $status in
                "Running")
                    echo "  ✅ $service: $status"
                    ;;
                *)
                    echo "  ⚠️  $service: $status"
                    ;;
            esac
        else
            echo "  ❌ $service: Not deployed"
        fi
    done
    
    # Show access URLs
    echo
    echo "Access URLs:"
    echo "  Frontend:        http://localhost:3000"
    echo "  API:            http://localhost:8000"
    echo "  API Docs:       http://localhost:8000/docs"
    echo "  PostgreSQL:     localhost:5432"
    echo "  Redis:          localhost:6379"
    echo "  Elasticsearch:  http://localhost:9200"
    echo "  vLLM API:       http://localhost:8001"
    echo "  Grafana:        http://localhost:3000 (admin/admin)"
    echo "  Audio Processor: http://localhost:8002"
}

# Function to show logs
logs() {
    local service=${1:-"api"}
    local follow=${2:-"false"}
    
    check_cluster
    
    local deployment_name
    case $service in
        "api"|"frontend"|"vllm"|"audio-processor")
            deployment_name="$CLUSTER_NAME-$service"
            ;;
        "postgres"|"postgresql")
            deployment_name="$CLUSTER_NAME-postgresql"
            ;;
        "redis")
            deployment_name="$CLUSTER_NAME-redis-master"
            ;;
        "elasticsearch")
            deployment_name="$CLUSTER_NAME-elasticsearch-master"
            ;;
        *)
            log_error "Unknown service: $service"
            echo "Available services: api, frontend, vllm, audio-processor, postgresql, redis, elasticsearch"
            exit 1
            ;;
    esac
    
    if [[ $follow == "true" ]]; then
        kubectl logs -f deployment/$deployment_name -n $NAMESPACE
    else
        kubectl logs deployment/$deployment_name -n $NAMESPACE --tail=100
    fi
}

# Function to restart a service
restart() {
    local service=$1
    
    check_cluster
    
    case $service in
        "api"|"frontend"|"vllm"|"audio-processor")
            deployment_name="$CLUSTER_NAME-$service"
            ;;
        *)
            log_error "Cannot restart $service. Available services: api, frontend, vllm, audio-processor"
            exit 1
            ;;
    esac
    
    log_info "Restarting $service..."
    kubectl rollout restart deployment/$deployment_name -n $NAMESPACE
    kubectl rollout status deployment/$deployment_name -n $NAMESPACE
    log_success "$service restarted successfully"
}

# Function to update Helm deployment
update() {
    local values_file=${1:-"values-development.yaml"}
    
    check_cluster
    
    log_info "Updating GameMaster's Companion deployment..."
    
    helm upgrade gmc-dev \
        "$PROJECT_ROOT/infrastructure/helm/gmc-dev" \
        --namespace $NAMESPACE \
        --values "$PROJECT_ROOT/infrastructure/helm/gmc-dev/values.yaml" \
        --values "$PROJECT_ROOT/infrastructure/helm/gmc-dev/$values_file" \
        --wait \
        --timeout 10m
    
    log_success "Deployment updated successfully"
}

# Function to port-forward services for local access
port_forward() {
    local service=${1:-"all"}
    
    check_cluster
    
    case $service in
        "api")
            kubectl port-forward -n $NAMESPACE svc/$CLUSTER_NAME-api 8000:8000 &
            ;;
        "frontend")
            kubectl port-forward -n $NAMESPACE svc/$CLUSTER_NAME-frontend 3000:3000 &
            ;;
        "postgres"|"postgresql")
            kubectl port-forward -n $NAMESPACE svc/$CLUSTER_NAME-postgresql 5432:5432 &
            ;;
        "redis")
            kubectl port-forward -n $NAMESPACE svc/$CLUSTER_NAME-redis-master 6379:6379 &
            ;;
        "elasticsearch")
            kubectl port-forward -n $NAMESPACE svc/$CLUSTER_NAME-elasticsearch 9200:9200 &
            ;;
        "vllm")
            kubectl port-forward -n $NAMESPACE svc/$CLUSTER_NAME-vllm 8001:8000 &
            ;;
        "audio")
            kubectl port-forward -n $NAMESPACE svc/$CLUSTER_NAME-audio-processor 8002:8001 &
            ;;
        "grafana")
            kubectl port-forward -n $NAMESPACE svc/$CLUSTER_NAME-kube-prometheus-stack-grafana 3000:80 &
            ;;
        "all")
            log_info "Starting port forwarding for all services..."
            kubectl port-forward -n $NAMESPACE svc/$CLUSTER_NAME-api 8000:8000 &
            kubectl port-forward -n $NAMESPACE svc/$CLUSTER_NAME-frontend 3000:3000 &
            kubectl port-forward -n $NAMESPACE svc/$CLUSTER_NAME-postgresql 5432:5432 &
            kubectl port-forward -n $NAMESPACE svc/$CLUSTER_NAME-redis-master 6379:6379 &
            kubectl port-forward -n $NAMESPACE svc/$CLUSTER_NAME-elasticsearch 9200:9200 &
            kubectl port-forward -n $NAMESPACE svc/$CLUSTER_NAME-vllm 8001:8000 &
            kubectl port-forward -n $NAMESPACE svc/$CLUSTER_NAME-audio-processor 8002:8001 &
            ;;
        *)
            log_error "Unknown service: $service"
            echo "Available services: api, frontend, postgresql, redis, elasticsearch, vllm, audio, grafana, all"
            exit 1
            ;;
    esac
    
    if [[ $service != "all" ]]; then
        log_success "Port forwarding started for $service"
        log_info "Press Ctrl+C to stop"
        wait
    else
        log_success "Port forwarding started for all services"
        log_info "Press Ctrl+C to stop all"
        wait
    fi
}

# Function to run database migrations
migrate() {
    check_cluster
    
    log_info "Running database migrations..."
    
    # Wait for API to be ready
    wait_for_pod "api" 120
    
    # Run migrations
    kubectl exec -n $NAMESPACE deployment/$CLUSTER_NAME-api -- \
        python -m alembic upgrade head
    
    log_success "Database migrations completed"
}

# Function to seed test data
seed() {
    check_cluster
    
    log_info "Seeding test data..."
    
    # Wait for API to be ready
    wait_for_pod "api" 120
    
    # Run seed script
    kubectl exec -n $NAMESPACE deployment/$CLUSTER_NAME-api -- \
        python -m scripts.seed_dev_data
    
    log_success "Test data seeded successfully"
}

# Function to clean up development environment
clean() {
    local confirm=${1:-""}
    
    if [[ $confirm != "--confirm" ]]; then
        echo "This will delete the entire development cluster and all data."
        read -p "Are you sure? Type 'yes' to confirm: " -r
        if [[ ! $REPLY == "yes" ]]; then
            log_info "Cleanup cancelled"
            exit 0
        fi
    fi
    
    log_info "Cleaning up development environment..."
    
    # Delete cluster
    if kind get clusters | grep -q "^$CLUSTER_NAME$"; then
        kind delete cluster --name $CLUSTER_NAME
        log_success "Kind cluster deleted"
    fi
    
    # Clean up local data
    if [[ -d "$PROJECT_ROOT/dev-data" ]]; then
        rm -rf "$PROJECT_ROOT/dev-data"
        log_success "Local data cleaned"
    fi
    
    if [[ -d "$PROJECT_ROOT/dev-models" ]]; then
        rm -rf "$PROJECT_ROOT/dev-models"
        log_success "Model cache cleaned"
    fi
    
    log_success "Development environment cleaned up"
}

# Function to show help
help() {
    echo "GameMaster's Companion Development Workflow"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  status              Show cluster and services status"
    echo "  logs <service>      Show logs for a service (add 'follow' to follow)"
    echo "  restart <service>   Restart a service"
    echo "  update [values]     Update Helm deployment (default: values-development.yaml)"
    echo "  port-forward <svc>  Port forward services (api, frontend, postgres, redis, etc.)"
    echo "  migrate             Run database migrations"
    echo "  seed                Seed test data"
    echo "  clean [--confirm]   Clean up development environment"
    echo "  help                Show this help message"
    echo
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 logs api"
    echo "  $0 logs api follow"
    echo "  $0 restart api"
    echo "  $0 port-forward all"
    echo "  $0 update"
    echo "  $0 migrate"
    echo "  $0 seed"
    echo "  $0 clean"
}

# Main command router
main() {
    case ${1:-""} in
        "status")
            status
            ;;
        "logs")
            logs "${2:-api}" "${3:-false}"
            ;;
        "restart")
            if [[ -z "${2:-}" ]]; then
                log_error "Service name required for restart"
                exit 1
            fi
            restart "$2"
            ;;
        "update")
            update "${2:-values-development.yaml}"
            ;;
        "port-forward"|"pf")
            port_forward "${2:-all}"
            ;;
        "migrate")
            migrate
            ;;
        "seed")
            seed
            ;;
        "clean")
            clean "${2:-}"
            ;;
        "help"|"--help"|"-h")
            help
            ;;
        "")
            log_error "No command specified"
            help
            exit 1
            ;;
        *)
            log_error "Unknown command: $1"
            help
            exit 1
            ;;
    esac
}

main "$@"