# GameMaster's Companion - Kind Cluster Setup Script (PowerShell)
# Sets up a complete local development environment with Kind

[CmdletBinding()]
param(
    [switch]$SkipConfirmation
)

# Enable strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Configuration
$CLUSTER_NAME = "gmc-dev"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent $SCRIPT_DIR)
$INFRASTRUCTURE_DIR = Join-Path $PROJECT_ROOT "infrastructure"

# Console colors
function Write-Info { 
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue 
}

function Write-Success { 
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green 
}

function Write-Warning { 
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow 
}

function Write-Error { 
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red 
}

# Check prerequisites
function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    $missingTools = @()
    
    # Check for required tools
    $tools = @("kind", "kubectl", "helm", "docker")
    foreach ($tool in $tools) {
        try {
            $null = Get-Command $tool -ErrorAction Stop
        }
        catch {
            $missingTools += $tool
        }
    }
    
    if ($missingTools.Count -gt 0) {
        Write-Error "Missing required tools: $($missingTools -join ', ')"
        Write-Info "Please install missing tools and run again."
        Write-Info "Installation guides:"
        Write-Info "  kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
        Write-Info "  kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/"
        Write-Info "  helm: https://helm.sh/docs/intro/install/"
        Write-Info "  docker: https://docs.docker.com/desktop/install/windows-install/"
        exit 1
    }
    
    # Check if Docker daemon is running
    try {
        docker info | Out-Null
    }
    catch {
        Write-Error "Docker daemon is not running. Please start Docker Desktop and try again."
        exit 1
    }
    
    Write-Success "All prerequisites satisfied"
}

# Create required directories
function New-RequiredDirectories {
    Write-Info "Creating required directories..."
    
    $directories = @(
        "$PROJECT_ROOT\dev-data",
        "$PROJECT_ROOT\dev-models",
        "$PROJECT_ROOT\dev-data\postgres",
        "$PROJECT_ROOT\dev-data\redis",
        "$PROJECT_ROOT\dev-data\elasticsearch",
        "$PROJECT_ROOT\dev-data\prometheus"
    )
    
    foreach ($dir in $directories) {
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    
    Write-Success "Directories created"
}

# Create Kind cluster
function New-KindCluster {
    Write-Info "Creating Kind cluster '$CLUSTER_NAME'..."
    
    # Check if cluster already exists
    $existingClusters = kind get clusters 2>$null
    if ($existingClusters -contains $CLUSTER_NAME) {
        Write-Warning "Cluster '$CLUSTER_NAME' already exists"
        
        if (!$SkipConfirmation) {
            $response = Read-Host "Do you want to delete and recreate it? (y/N)"
            if ($response -match "^[Yy]$") {
                Write-Info "Deleting existing cluster..."
                kind delete cluster --name $CLUSTER_NAME
            }
            else {
                Write-Info "Using existing cluster"
                return
            }
        }
    }
    
    # Create cluster with configuration
    $configPath = Join-Path $INFRASTRUCTURE_DIR "kind-cluster-config.yaml"
    kind create cluster --name $CLUSTER_NAME --config $configPath
    
    # Wait for cluster to be ready
    Write-Info "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    Write-Success "Kind cluster '$CLUSTER_NAME' created and ready"
}

# Install required components
function Install-ClusterComponents {
    Write-Info "Installing required cluster components..."
    
    # Install local-path-provisioner for storage
    Write-Info "Installing local-path-provisioner..."
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
    
    # Install NGINX Ingress Controller
    Write-Info "Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    
    # Wait for ingress controller to be ready
    Write-Info "Waiting for ingress controller to be ready..."
    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s
    
    # Apply storage classes
    Write-Info "Applying storage classes..."
    $storageClassPath = Join-Path $INFRASTRUCTURE_DIR "storage-classes.yaml"
    kubectl apply -f $storageClassPath
    
    Write-Success "Cluster components installed"
}

# Add Helm repositories
function Add-HelmRepositories {
    Write-Info "Setting up Helm repositories..."
    
    # Add required repositories
    $repos = @{
        "bitnami" = "https://charts.bitnami.com/bitnami"
        "prometheus-community" = "https://prometheus-community.github.io/helm-charts"
        "elastic" = "https://helm.elastic.co"
        "ingress-nginx" = "https://kubernetes.github.io/ingress-nginx"
    }
    
    foreach ($repo in $repos.GetEnumerator()) {
        helm repo add $repo.Key $repo.Value
    }
    
    # Update repositories
    helm repo update
    
    Write-Success "Helm repositories configured"
}

# Install GameMaster's Companion
function Install-GMC {
    Write-Info "Installing GameMaster's Companion..."
    
    # Create namespace
    kubectl create namespace gmc-dev --dry-run=client -o yaml | kubectl apply -f -
    
    # Build Helm chart dependencies
    $helmChartPath = Join-Path $INFRASTRUCTURE_DIR "helm\gmc-dev"
    $valuesPath = Join-Path $INFRASTRUCTURE_DIR "helm\gmc-dev\values.yaml"
    $devValuesPath = Join-Path $INFRASTRUCTURE_DIR "helm\gmc-dev\values-development.yaml"
    
    Write-Info "Building Helm chart dependencies..."
    Push-Location $helmChartPath
    try {
        helm dependency build
    }
    finally {
        Pop-Location
    }
    
    # Install Helm chart
    helm upgrade --install gmc-dev $helmChartPath --namespace gmc-dev --values $valuesPath --values $devValuesPath --wait --timeout 20m
    
    Write-Success "GameMaster's Companion installed"
}

# Display connection information
function Show-ConnectionInfo {
    Write-Info "Deployment complete! Connection information:"
    Write-Host ""
    Write-Host "Cluster: $CLUSTER_NAME"
    Write-Host "Context: kind-$CLUSTER_NAME"
    Write-Host ""
    Write-Host "Services accessible at:"
    Write-Host "  Frontend:        http://localhost:3000"
    Write-Host "  API:            http://localhost:8000"
    Write-Host "  PostgreSQL:     localhost:5432"
    Write-Host "  Redis:          localhost:6379"
    Write-Host "  Elasticsearch:  localhost:9200"
    Write-Host "  vLLM API:       localhost:8001"
    Write-Host "  Grafana:        http://localhost:3000 (admin/admin)"
    Write-Host "  Audio Processor: localhost:8002"
    Write-Host ""
    Write-Host "To access the application:"
    Write-Host "  1. Add '127.0.0.1 gmc.local' to your C:\Windows\System32\drivers\etc\hosts file"
    Write-Host "  2. Open http://gmc.local in your browser"
    Write-Host ""
    Write-Host "Useful commands:"
    Write-Host "  kubectl get pods -n gmc-dev"
    Write-Host "  kubectl logs -f deployment/gmc-dev-api -n gmc-dev"
    Write-Host "  helm status gmc-dev -n gmc-dev"
    Write-Host "  kind delete cluster --name $CLUSTER_NAME  # To clean up"
    Write-Host ""
    Write-Host "PowerShell development workflow:"
    Write-Host "  .\infrastructure\scripts\dev-workflow.ps1 status"
    Write-Host "  .\infrastructure\scripts\dev-workflow.ps1 logs api"
    Write-Host "  .\infrastructure\scripts\dev-workflow.ps1 port-forward all"
}

# Cleanup function
function Invoke-Cleanup {
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Setup failed. You may want to clean up:"
        Write-Host "  kind delete cluster --name $CLUSTER_NAME"
    }
}

# Main execution
function Main {
    Write-Info "Starting GameMaster's Companion Kind cluster setup..."
    
    try {
        Test-Prerequisites
        New-RequiredDirectories
        New-KindCluster
        Install-ClusterComponents
        Add-HelmRepositories
        Install-GMC
        Show-ConnectionInfo
        
        Write-Success "Setup complete! GameMaster's Companion is ready for development."
    }
    catch {
        Write-Error "Setup failed: $_"
        Invoke-Cleanup
        exit 1
    }
}

# Run main function
Main