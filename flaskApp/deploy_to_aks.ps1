# Flask App AKS Deployment Script (PowerShell)
# This script deploys the Flask app to AKS using ACR Build

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$true)]
    [string]$AcrName,
    
    [Parameter(Mandatory=$true)]
    [string]$AksClusterName,
    
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName
)

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"

function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Red
}

# Check prerequisites
Write-Status "Checking prerequisites..."

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI is not installed or not in PATH"
    exit 1
}

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Error "kubectl is not installed or not in PATH"
    exit 1
}

Write-Status "All prerequisites are satisfied."

# Step 1: Create Resource Group
Write-Status "Creating resource group: $ResourceGroupName"
az group create --name $ResourceGroupName --location $Location

# Step 2: Create Azure Container Registry
Write-Status "Creating Azure Container Registry: $AcrName"
az acr create --resource-group $ResourceGroupName --name $AcrName --sku Basic --admin-enabled true

# Step 3: Create Azure Key Vault
Write-Status "Creating Azure Key Vault: $KeyVaultName"
az keyvault create --name $KeyVaultName --resource-group $ResourceGroupName --location $Location

# Step 4: Add a secret to Key Vault
Write-Status "Adding secret to Key Vault"
$secretValue = "SUCCESS-CODE-$(Get-Random -Minimum 1000 -Maximum 9999)"
az keyvault secret set --vault-name $KeyVaultName --name "success-code" --value $secretValue
Write-Status "Secret added with value: $secretValue"

# Step 5: Create AKS Cluster
Write-Status "Creating AKS cluster: $AksClusterName"
az aks create `
    --resource-group $ResourceGroupName `
    --name $AksClusterName `
    --node-count 2 `
    --enable-addons monitoring `
    --generate-ssh-keys `
    --attach-acr $AcrName

# Step 6: Get AKS credentials
Write-Status "Getting AKS credentials"
az aks get-credentials --resource-group $ResourceGroupName --name $AksClusterName --overwrite-existing

# Step 7: Build and push image using ACR Build
Write-Status "Building and pushing Docker image using ACR Build"
az acr build --registry $AcrName --image flask-app:latest .

# Step 8: Update Kubernetes manifests
Write-Status "Updating Kubernetes manifests"

# Update deployment.yaml
$deploymentContent = Get-Content "k8s/deployment.yaml" -Raw
$deploymentContent = $deploymentContent -replace "flask-app:latest", "$AcrName.azurecr.io/flask-app:latest"
$deploymentContent = $deploymentContent -replace "https://your-keyvault-name.vault.azure.net/", "https://$KeyVaultName.vault.azure.net/"
$deploymentContent | Set-Content "k8s/deployment.yaml"

# Step 9: Deploy to AKS
Write-Status "Deploying to AKS"
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/service-account.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Step 10: Wait for deployment
Write-Status "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/flask-app -n flask-app

# Step 11: Show status
Write-Status "Deployment completed! Checking status..."
Write-Host ""
kubectl get pods -n flask-app
Write-Host ""
kubectl get services -n flask-app

# Get external IP
$externalIP = kubectl get service flask-app-service -n flask-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null

if ($externalIP) {
    Write-Status "Application is accessible at: http://$externalIP"
    Write-Status "Test endpoints:"
    Write-Host "  Health check: http://$externalIP/"
    Write-Host "  Get secret: http://$externalIP/api/secret"
    Write-Host "  Status: http://$externalIP/api/status"
} else {
    Write-Warning "External IP is still pending. Please wait a few minutes and check again."
}

Write-Host ""
Write-Status "Deployment completed successfully! 🎉"
Write-Warning "Note: You may need to configure Azure Workload Identity for Key Vault access in production."
Write-Host ""
Write-Status "To check logs: kubectl logs -n flask-app deployment/flask-app"
Write-Status "To delete resources: az group delete --name $ResourceGroupName --yes"
