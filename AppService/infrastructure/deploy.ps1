# Azure App Service Demo Deployment Script
# This script deploys the infrastructure and application for WAF and Private Endpoint testing

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-appservice-demo",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory=$false)]
    [string]$NamePrefix = "appservice-demo",
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev"
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting Azure App Service Demo Deployment" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Check if Azure CLI is installed
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Host "✅ Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Green
} catch {
    Write-Host "❌ Azure CLI is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Azure CLI from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Yellow
    exit 1
}

# Login to Azure (if not already logged in)
Write-Host "🔐 Checking Azure login status..." -ForegroundColor Yellow
try {
    $account = az account show --output json | ConvertFrom-Json
    Write-Host "✅ Logged in as: $($account.user.name)" -ForegroundColor Green
    Write-Host "   Subscription: $($account.name)" -ForegroundColor Green
    Write-Host "   Tenant: $($account.tenantId)" -ForegroundColor Green
} catch {
    Write-Host "❌ Not logged in to Azure. Please run 'az login'" -ForegroundColor Red
    exit 1
}

# Set subscription if provided
if ($SubscriptionId) {
    Write-Host "🔄 Setting subscription to: $SubscriptionId" -ForegroundColor Yellow
    az account set --subscription $SubscriptionId
}

# Create resource group
Write-Host "📦 Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location

# Deploy infrastructure
Write-Host "🏗️  Deploying infrastructure..." -ForegroundColor Yellow
$deploymentName = "appservice-demo-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

$deploymentResult = az deployment group create `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --template-file "main.bicep" `
    --parameters @parameters.json `
    --parameters resourceGroupName=$ResourceGroupName location=$Location namePrefix=$NamePrefix environment=$Environment `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Infrastructure deployment completed successfully!" -ForegroundColor Green
    
    # Get outputs
    $outputs = $deploymentResult.properties.outputs
    $appServiceName = $outputs.appServiceName.value
    $appServiceUrl = $outputs.appServiceUrl.value
    $keyVaultName = $outputs.keyVaultName.value
    $applicationGatewayUrl = $outputs.applicationGatewayUrl.value
    $appServicePrincipalId = $outputs.appServicePrincipalId.value
    
    Write-Host ""
    Write-Host "📋 Deployment Summary:" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    Write-Host "App Service Name: $appServiceName" -ForegroundColor White
    Write-Host "App Service URL: $appServiceUrl" -ForegroundColor White
    Write-Host "Key Vault Name: $keyVaultName" -ForegroundColor White
    Write-Host "Application Gateway URL: $applicationGatewayUrl" -ForegroundColor White
    Write-Host "App Service Principal ID: $appServicePrincipalId" -ForegroundColor White
    
    # Deploy application code
    Write-Host ""
    Write-Host "📦 Deploying application code..." -ForegroundColor Yellow
    
    # Create deployment package
    $zipFile = "app-deployment.zip"
    if (Test-Path $zipFile) {
        Remove-Item $zipFile
    }
    
    # Create zip file with application files
    Compress-Archive -Path "../package.json", "../server.js", "../public" -DestinationPath $zipFile -Force
    
    # Deploy to App Service
    Write-Host "🚀 Deploying to App Service..." -ForegroundColor Yellow
    az webapp deployment source config-zip `
        --resource-group $ResourceGroupName `
        --name $appServiceName `
        --src $zipFile
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Application deployment completed successfully!" -ForegroundColor Green
        
        # Clean up zip file
        Remove-Item $zipFile -ErrorAction SilentlyContinue
        
        Write-Host ""
        Write-Host "🎉 Deployment Complete!" -ForegroundColor Green
        Write-Host "======================" -ForegroundColor Green
        Write-Host ""
        Write-Host "🔗 Access your application:" -ForegroundColor Cyan
        Write-Host "   Direct App Service URL: $appServiceUrl" -ForegroundColor White
        Write-Host "   Through Application Gateway: $applicationGatewayUrl" -ForegroundColor White
        Write-Host ""
        Write-Host "🧪 Testing Instructions:" -ForegroundColor Cyan
        Write-Host "   1. Open the application URL in your browser" -ForegroundColor White
        Write-Host "   2. Enter any text to test basic functionality" -ForegroundColor White
        Write-Host "   3. Enter 'secret' to test Key Vault integration" -ForegroundColor White
        Write-Host "   4. Test WAF by trying malicious requests" -ForegroundColor White
        Write-Host ""
        Write-Host "🔧 Key Vault Configuration:" -ForegroundColor Cyan
        Write-Host "   Key Vault Name: $keyVaultName" -ForegroundColor White
        Write-Host "   Secret Name: demo-secret" -ForegroundColor White
        Write-Host "   Managed Identity: $appServicePrincipalId" -ForegroundColor White
        
    } else {
        Write-Host "❌ Application deployment failed!" -ForegroundColor Red
        exit 1
    }
    
} else {
    Write-Host "❌ Infrastructure deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✨ Happy testing! 🎯" -ForegroundColor Green
