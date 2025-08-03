# GameMaster's Companion Development Workflow Scripts (PowerShell)
# Provides common development tasks for local Kind environment

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet("status", "logs", "restart", "update", "port-forward", "pf", "migrate", "seed", "clean", "help")]
    [string]$Command = "help",
    
    [Parameter(Position=1)]
    [string]$Service = "",
    
    [Parameter(Position=2)]
    [string]$Option = "",
    
    [switch]$Confirm,
    [switch]$Follow
)

# Enable strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Configuration
$CLUSTER_NAME = "gmc-dev"
$NAMESPACE = "gmc-dev"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent $SCRIPT_DIR)

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

# Function to check if cluster is running
function Test-Cluster {
    $existingClusters = kind get clusters 2>$null
    if ($existingClusters -notcontains $CLUSTER_NAME) {
        Write-Error "Kind cluster '$CLUSTER_NAME' not found. Run setup-kind-cluster.ps1 first."
        exit 1
    }
    
    try {
        kubectl cluster-info --context "kind-$CLUSTER_NAME" | Out-Null
    }
    catch {
        Write-Error "Cannot connect to cluster '$CLUSTER_NAME'. Is it running?"
        exit 1
    }
}

# Function to get pod status
function Get-PodStatus {
    param([string]$ServiceName)
    
    try {
        $status = kubectl get pods -n $NAMESPACE -l "app.kubernetes.io/component=$ServiceName" -o jsonpath='{.items[0].status.phase}' 2>$null
        if ([string]::IsNullOrEmpty($status)) {
            return "NotFound"
        }
        return $status
    }
    catch {
        return "NotFound"
    }
}

# Function to wait for pod to be ready
function Wait-ForPod {
    param(
        [string]$ServiceName,
        [int]$TimeoutSeconds = 300
    )
    
    Write-Info "Waiting for $ServiceName to be ready..."
    kubectl wait --for=condition=Ready pod -l "app.kubernetes.io/component=$ServiceName" -n $NAMESPACE --timeout="${TimeoutSeconds}s"
}

# Function to show cluster status
function Show-Status {
    Write-Info "GameMaster's Companion Development Environment Status"
    Write-Host ""
    
    # Check cluster
    $existingClusters = kind get clusters 2>$null
    if ($existingClusters -contains $CLUSTER_NAME) {
        Write-Host "✅ Kind cluster '$CLUSTER_NAME' is running"
    }
    else {
        Write-Host "❌ Kind cluster '$CLUSTER_NAME' not found"
        return
    }
    
    # Check namespace
    try {
        kubectl get namespace $NAMESPACE | Out-Null
        Write-Host "✅ Namespace '$NAMESPACE' exists"
    }
    catch {
        Write-Host "❌ Namespace '$NAMESPACE' not found"
        return
    }
    
    # Check services
    Write-Host ""
    Write-Host "Service Status:"
    $services = @("api", "frontend", "vllm", "audio-processor")
    foreach ($service in $services) {
        $status = Get-PodStatus $service
        switch ($status) {
            "Running" { Write-Host "  ✅ $service`: $status" }
            "Pending" { Write-Host "  🔄 $service`: $status" }
            "NotFound" { Write-Host "  ❌ $service`: Not deployed" }
            default { Write-Host "  ⚠️  $service`: $status" }
        }
    }
    
    # Check databases
    Write-Host ""
    Write-Host "Data Services:"
    $dataServices = @("postgresql", "redis", "elasticsearch")
    foreach ($service in $dataServices) {
        try {
            kubectl get pods -n $NAMESPACE -l "app.kubernetes.io/name=$service" | Out-Null
            $status = kubectl get pods -n $NAMESPACE -l "app.kubernetes.io/name=$service" -o jsonpath='{.items[0].status.phase}' 2>$null
            if ($status -eq "Running") {
                Write-Host "  ✅ $service`: $status"
            }
            else {
                Write-Host "  ⚠️  $service`: $status"
            }
        }
        catch {
            Write-Host "  ❌ $service`: Not deployed"
        }
    }
    
    # Show access URLs
    Write-Host ""
    Write-Host "Access URLs:"
    Write-Host "  Frontend:        http://localhost:3000"
    Write-Host "  API:            http://localhost:8000"
    Write-Host "  API Docs:       http://localhost:8000/docs"
    Write-Host "  PostgreSQL:     localhost:5432"
    Write-Host "  Redis:          localhost:6379"
    Write-Host "  Elasticsearch:  http://localhost:9200"
    Write-Host "  vLLM API:       http://localhost:8001"
    Write-Host "  Grafana:        http://localhost:3000 (admin/admin)"
    Write-Host "  Audio Processor: http://localhost:8002"
}

# Function to show logs
function Show-Logs {
    param(
        [string]$ServiceName = "api",
        [bool]$FollowLogs = $false
    )
    
    Test-Cluster
    
    $deploymentName = switch ($ServiceName) {
        { $_ -in @("api", "frontend", "vllm", "audio-processor") } { "$CLUSTER_NAME-$ServiceName" }
        { $_ -in @("postgres", "postgresql") } { "$CLUSTER_NAME-postgresql" }
        "redis" { "$CLUSTER_NAME-redis-master" }
        "elasticsearch" { "$CLUSTER_NAME-elasticsearch-master" }
        default { 
            Write-Error "Unknown service: $ServiceName"
            Write-Host "Available services: api, frontend, vllm, audio-processor, postgresql, redis, elasticsearch"
            exit 1
        }
    }
    
    if ($FollowLogs) {
        kubectl logs -f deployment/$deploymentName -n $NAMESPACE
    }
    else {
        kubectl logs deployment/$deploymentName -n $NAMESPACE --tail=100
    }
}

# Function to restart a service
function Restart-Service {
    param([string]$ServiceName)
    
    Test-Cluster
    
    $deploymentName = switch ($ServiceName) {
        { $_ -in @("api", "frontend", "vllm", "audio-processor") } { "$CLUSTER_NAME-$ServiceName" }
        default {
            Write-Error "Cannot restart $ServiceName. Available services: api, frontend, vllm, audio-processor"
            exit 1
        }
    }
    
    Write-Info "Restarting $ServiceName..."
    kubectl rollout restart deployment/$deploymentName -n $NAMESPACE
    kubectl rollout status deployment/$deploymentName -n $NAMESPACE
    Write-Success "$ServiceName restarted successfully"
}

# Function to update Helm deployment
function Update-Deployment {
    param([string]$ValuesFile = "values-development.yaml")
    
    Test-Cluster
    
    Write-Info "Updating GameMaster's Companion deployment..."
    
    $helmChartPath = Join-Path $PROJECT_ROOT "infrastructure\helm\gmc-dev"
    $valuesPath = Join-Path $PROJECT_ROOT "infrastructure\helm\gmc-dev\values.yaml"
    $devValuesPath = Join-Path $PROJECT_ROOT "infrastructure\helm\gmc-dev\$ValuesFile"
    
    helm upgrade gmc-dev $helmChartPath --namespace $NAMESPACE --values $valuesPath --values $devValuesPath --wait --timeout 10m
    
    Write-Success "Deployment updated successfully"
}

# Function to port-forward services for local access
function Start-PortForward {
    param([string]$ServiceName = "all")
    
    Test-Cluster
    
    $jobs = @()
    
    switch ($ServiceName) {
        "api" {
            $jobs += Start-Job -ScriptBlock { kubectl port-forward -n $using:NAMESPACE svc/$using:CLUSTER_NAME-api 8000:8000 }
        }
        "frontend" {
            $jobs += Start-Job -ScriptBlock { kubectl port-forward -n $using:NAMESPACE svc/$using:CLUSTER_NAME-frontend 3000:3000 }
        }
        { $_ -in @("postgres", "postgresql") } {
            $jobs += Start-Job -ScriptBlock { kubectl port-forward -n $using:NAMESPACE svc/$using:CLUSTER_NAME-postgresql 5432:5432 }
        }
        "redis" {
            $jobs += Start-Job -ScriptBlock { kubectl port-forward -n $using:NAMESPACE svc/$using:CLUSTER_NAME-redis-master 6379:6379 }
        }
        "elasticsearch" {
            $jobs += Start-Job -ScriptBlock { kubectl port-forward -n $using:NAMESPACE svc/$using:CLUSTER_NAME-elasticsearch 9200:9200 }
        }
        "vllm" {
            $jobs += Start-Job -ScriptBlock { kubectl port-forward -n $using:NAMESPACE svc/$using:CLUSTER_NAME-vllm 8001:8000 }
        }
        "audio" {
            $jobs += Start-Job -ScriptBlock { kubectl port-forward -n $using:NAMESPACE svc/$using:CLUSTER_NAME-audio-processor 8002:8001 }
        }
        "grafana" {
            $jobs += Start-Job -ScriptBlock { kubectl port-forward -n $using:NAMESPACE svc/$using:CLUSTER_NAME-kube-prometheus-stack-grafana 3000:80 }
        }
        "all" {
            Write-Info "Starting port forwarding for all services..."
            $jobs += Start-Job -ScriptBlock { kubectl port-forward -n $using:NAMESPACE svc/$using:CLUSTER_NAME-api 8000:8000 }
            $jobs += Start-Job -ScriptBlock { kubectl port-forward -n $using:NAMESPACE svc/$using:CLUSTER_NAME-frontend 3000:3000 }
            $jobs += Start-Job -ScriptBlock { kubectl port-forward -n $using:NAMESPACE svc/$using:CLUSTER_NAME-postgresql 5432:5432 }
            $jobs += Start-Job -ScriptBlock { kubectl port-forward -n $using:NAMESPACE svc/$using:CLUSTER_NAME-redis-master 6379:6379 }
            $jobs += Start-Job -ScriptBlock { kubectl port-forward -n $using:NAMESPACE svc/$using:CLUSTER_NAME-elasticsearch 9200:9200 }
            $jobs += Start-Job -ScriptBlock { kubectl port-forward -n $using:NAMESPACE svc/$using:CLUSTER_NAME-vllm 8001:8000 }
            $jobs += Start-Job -ScriptBlock { kubectl port-forward -n $using:NAMESPACE svc/$using:CLUSTER_NAME-audio-processor 8002:8001 }
        }
        default {
            Write-Error "Unknown service: $ServiceName"
            Write-Host "Available services: api, frontend, postgresql, redis, elasticsearch, vllm, audio, grafana, all"
            exit 1
        }
    }
    
    if ($ServiceName -ne "all") {
        Write-Success "Port forwarding started for $ServiceName"
        Write-Info "Press Ctrl+C to stop"
    }
    else {
        Write-Success "Port forwarding started for all services"
        Write-Info "Press Ctrl+C to stop all"
    }
    
    try {
        Wait-Job $jobs | Out-Null
    }
    finally {
        $jobs | Stop-Job
        $jobs | Remove-Job
    }
}

# Function to run database migrations
function Invoke-Migration {
    Test-Cluster
    
    Write-Info "Running database migrations..."
    
    # Wait for API to be ready
    Wait-ForPod "api" 120
    
    # Run migrations
    kubectl exec -n $NAMESPACE deployment/$CLUSTER_NAME-api -- python -m alembic upgrade head
    
    Write-Success "Database migrations completed"
}

# Function to seed test data
function Invoke-Seed {
    Test-Cluster
    
    Write-Info "Seeding test data..."
    
    # Wait for API to be ready
    Wait-ForPod "api" 120
    
    # Run seed script
    kubectl exec -n $NAMESPACE deployment/$CLUSTER_NAME-api -- python -m scripts.seed_dev_data
    
    Write-Success "Test data seeded successfully"
}

# Function to clean up development environment
function Invoke-Clean {
    param([bool]$SkipConfirmation = $false)
    
    if (!$SkipConfirmation -and !$Confirm) {
        Write-Host "This will delete the entire development cluster and all data."
        $response = Read-Host "Are you sure? Type 'yes' to confirm"
        if ($response -ne "yes") {
            Write-Info "Cleanup cancelled"
            return
        }
    }
    
    Write-Info "Cleaning up development environment..."
    
    # Delete cluster
    $existingClusters = kind get clusters 2>$null
    if ($existingClusters -contains $CLUSTER_NAME) {
        kind delete cluster --name $CLUSTER_NAME
        Write-Success "Kind cluster deleted"
    }
    
    # Clean up local data
    $devDataPath = Join-Path $PROJECT_ROOT "dev-data"
    if (Test-Path $devDataPath) {
        Remove-Item $devDataPath -Recurse -Force
        Write-Success "Local data cleaned"
    }
    
    $devModelsPath = Join-Path $PROJECT_ROOT "dev-models"
    if (Test-Path $devModelsPath) {
        Remove-Item $devModelsPath -Recurse -Force
        Write-Success "Model cache cleaned"
    }
    
    Write-Success "Development environment cleaned up"
}

# Function to show help
function Show-Help {
    Write-Host "GameMaster's Companion Development Workflow (PowerShell)"
    Write-Host ""
    Write-Host "Usage: .\dev-workflow.ps1 <command> [options]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  status              Show cluster and services status"
    Write-Host "  logs <service>      Show logs for a service (use -Follow to tail)"
    Write-Host "  restart <service>   Restart a service"
    Write-Host "  update [values]     Update Helm deployment (default: values-development.yaml)"
    Write-Host "  port-forward <svc>  Port forward services (api, frontend, postgres, redis, etc.)"
    Write-Host "  migrate             Run database migrations"
    Write-Host "  seed                Seed test data"
    Write-Host "  clean               Clean up development environment (use -Confirm to skip prompt)"
    Write-Host "  help                Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\dev-workflow.ps1 status"
    Write-Host "  .\dev-workflow.ps1 logs api"
    Write-Host "  .\dev-workflow.ps1 logs api -Follow"
    Write-Host "  .\dev-workflow.ps1 restart api"
    Write-Host "  .\dev-workflow.ps1 port-forward all"
    Write-Host "  .\dev-workflow.ps1 update"
    Write-Host "  .\dev-workflow.ps1 migrate"
    Write-Host "  .\dev-workflow.ps1 seed"
    Write-Host "  .\dev-workflow.ps1 clean -Confirm"
}

# Main command router
switch ($Command) {
    "status" {
        Show-Status
    }
    "logs" {
        if ([string]::IsNullOrEmpty($Service)) {
            $Service = "api"
        }
        if ($Option -eq "follow" -or $Follow) {
            Show-Logs $Service $true
        }
        else {
            Show-Logs $Service $false
        }
    }
    "restart" {
        if ([string]::IsNullOrEmpty($Service)) {
            Write-Error "Service name required for restart"
            exit 1
        }
        Restart-Service $Service
    }
    "update" {
        if ([string]::IsNullOrEmpty($Service)) {
            $Service = "values-development.yaml"
        }
        Update-Deployment $Service
    }
    { $_ -in @("port-forward", "pf") } {
        if ([string]::IsNullOrEmpty($Service)) {
            $Service = "all"
        }
        Start-PortForward $Service
    }
    "migrate" {
        Invoke-Migration
    }
    "seed" {
        Invoke-Seed
    }
    "clean" {
        Invoke-Clean $Confirm
    }
    "help" {
        Show-Help
    }
    default {
        Write-Error "Unknown command: $Command"
        Show-Help
        exit 1
    }
}