# Minimal Flask App Deployment Script
# This script creates the basic infrastructure we can control

Write-Host "=== Minimal Flask App Setup ===" -ForegroundColor Green
Write-Host "This script will set up what we can in your managed environment" -ForegroundColor Yellow
Write-Host ""

# Generate unique names
$timestamp = Get-Date -Format "MMddHHmm"
$resourceGroupName = "flask-app-rg-$timestamp"
$acrName = "flaskappacr$timestamp"

Write-Host "Resource Group: $resourceGroupName" -ForegroundColor Yellow
Write-Host "ACR Name: $acrName" -ForegroundColor Yellow
Write-Host ""

# Step 1: Create Resource Group
Write-Host "Step 1: Creating Resource Group..." -ForegroundColor Green
az group create --name $resourceGroupName --location eastus

# Step 2: Create Azure Container Registry
Write-Host "Step 2: Creating Azure Container Registry..." -ForegroundColor Green
az acr create --resource-group $resourceGroupName --name $acrName --sku Basic --admin-enabled true

# Step 3: Build and push image using ACR Build
Write-Host "Step 3: Building and pushing Docker image..." -ForegroundColor Green
az acr build --registry $acrName --image flask-app:latest .

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host "✅ Resource Group created: $resourceGroupName" -ForegroundColor Green
Write-Host "✅ Container Registry created: $acrName" -ForegroundColor Green
Write-Host "✅ Docker image built and pushed" -ForegroundColor Green
Write-Host ""
Write-Host "Your image is available at: $acrName.azurecr.io/flask-app:latest" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. You'll need to create an AKS cluster manually in the Azure portal" -ForegroundColor White
Write-Host "2. Or ask your admin to enable the Microsoft.ContainerService provider" -ForegroundColor White
Write-Host "3. Once AKS is available, you can deploy using the k8s manifests" -ForegroundColor White
Write-Host ""
Write-Host "To delete resources: az group delete --name $resourceGroupName --yes" -ForegroundColor Red
