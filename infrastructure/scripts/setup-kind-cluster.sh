#!/bin/bash
# GameMaster's Companion - Kind Cluster Setup Script
# Sets up a complete local development environment with Kind

set -euo pipefail

# Configuration
CLUSTER_NAME="gmc-dev"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
INFRASTRUCTURE_DIR="$PROJECT_ROOT/infrastructure"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v kind &> /dev/null; then
        missing_tools+=("kind")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install missing tools and run again."
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker and try again."
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

# Create required directories
create_directories() {
    log_info "Creating required directories..."
    
    mkdir -p "$PROJECT_ROOT/dev-data"
    mkdir -p "$PROJECT_ROOT/dev-models"
    
    # Create subdirectories for services
    mkdir -p "$PROJECT_ROOT/dev-data/postgres"
    mkdir -p "$PROJECT_ROOT/dev-data/redis"
    mkdir -p "$PROJECT_ROOT/dev-data/elasticsearch"
    mkdir -p "$PROJECT_ROOT/dev-data/prometheus"
    
    log_success "Directories created"
}

# Create Kind cluster
create_cluster() {
    log_info "Creating Kind cluster '$CLUSTER_NAME'..."
    
    # Check if cluster already exists
    if kind get clusters | grep -q "^$CLUSTER_NAME$"; then
        log_warning "Cluster '$CLUSTER_NAME' already exists"
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deleting existing cluster..."
            kind delete cluster --name "$CLUSTER_NAME"
        else
            log_info "Using existing cluster"
            return 0
        fi
    fi
    
    # Create cluster with configuration
    kind create cluster --name "$CLUSTER_NAME" --config "$INFRASTRUCTURE_DIR/kind-cluster-config.yaml"
    
    # Wait for cluster to be ready
    log_info "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    log_success "Kind cluster '$CLUSTER_NAME' created and ready"
}

# Install required components
install_components() {
    log_info "Installing required cluster components..."
    
    # Install local-path-provisioner for storage
    log_info "Installing local-path-provisioner..."
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
    
    # Install NGINX Ingress Controller
    log_info "Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    
    # Wait for ingress controller to be ready
    log_info "Waiting for ingress controller to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
    
    # Apply storage classes
    log_info "Applying storage classes..."
    kubectl apply -f "$INFRASTRUCTURE_DIR/storage-classes.yaml"
    
    log_success "Cluster components installed"
}

# Add Helm repositories
setup_helm_repos() {
    log_info "Setting up Helm repositories..."
    
    # Add required repositories
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add elastic https://helm.elastic.co
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    
    # Update repositories
    helm repo update
    
    log_success "Helm repositories configured"
}

# Install GameMaster's Companion
install_gmc() {
    log_info "Installing GameMaster's Companion..."
    
    # Create namespace
    kubectl create namespace gmc-dev --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Helm chart
    helm upgrade --install gmc-dev \
        "$INFRASTRUCTURE_DIR/helm/gmc-dev" \
        --namespace gmc-dev \
        --values "$INFRASTRUCTURE_DIR/helm/gmc-dev/values.yaml" \
        --values "$INFRASTRUCTURE_DIR/helm/gmc-dev/values-development.yaml" \
        --wait \
        --timeout 20m
    
    log_success "GameMaster's Companion installed"
}

# Display connection information
show_connection_info() {
    log_info "Deployment complete! Connection information:"
    echo
    echo "Cluster: $CLUSTER_NAME"
    echo "Context: kind-$CLUSTER_NAME"
    echo
    echo "Services accessible at:"
    echo "  Frontend:        http://localhost:3000"
    echo "  API:            http://localhost:8000"
    echo "  PostgreSQL:     localhost:5432"
    echo "  Redis:          localhost:6379"
    echo "  Elasticsearch:  localhost:9200"
    echo "  vLLM API:       localhost:8001"
    echo "  Grafana:        http://localhost:3000 (admin/admin)"
    echo "  Audio Processor: localhost:8002"
    echo
    echo "To access the application:"
    echo "  1. Add '127.0.0.1 gmc.local' to your /etc/hosts file"
    echo "  2. Open http://gmc.local in your browser"
    echo
    echo "Useful commands:"
    echo "  kubectl get pods -n gmc-dev"
    echo "  kubectl logs -f deployment/gmc-dev-api -n gmc-dev"
    echo "  helm status gmc-dev -n gmc-dev"
    echo "  kind delete cluster --name $CLUSTER_NAME  # To clean up"
}

# Cleanup function
cleanup() {
    if [ $? -ne 0 ]; then
        log_error "Setup failed. You may want to clean up:"
        echo "  kind delete cluster --name $CLUSTER_NAME"
    fi
}

# Main execution
main() {
    log_info "Starting GameMaster's Companion Kind cluster setup..."
    
    trap cleanup EXIT
    
    check_prerequisites
    create_directories
    create_cluster
    install_components
    setup_helm_repos
    install_gmc
    show_connection_info
    
    log_success "Setup complete! GameMaster's Companion is ready for development."
}

# Run main function
main "$@"