param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "test", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [string]$AdminUsername = "adminuser",
    [string]$AdminPassword = "P@ssword123!",
    [string]$VmSize = "Standard_D2s_v3"
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "=== Enterprise IaC Deployment ===" -ForegroundColor Green
Write-Host "Project: $ProjectName" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow
Write-Host ""

# Check if Azure CLI is installed
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Host "Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Green
} catch {
    Write-Host "Azure CLI not found. Please install Azure CLI first." -ForegroundColor Red
    exit 1
}

# Check if logged in
try {
    $account = az account show --output json | ConvertFrom-Json
    Write-Host "Logged in as: $($account.user.name)" -ForegroundColor Green
    Write-Host "Subscription: $($account.name)" -ForegroundColor Green
} catch {
    Write-Host "Not logged in to Azure. Please run 'az login' first." -ForegroundColor Red
    exit 1
}

# Set variables
$ResourceGroupName = "$ProjectName-$Environment-rg"
$TemplateFile = "deployments/$ProjectName/main.bicep"
$ParametersFile = "deployments/$ProjectName/parameters.json"

# Check if template files exist
if (-not (Test-Path $TemplateFile)) {
    Write-Host "Template file not found: $TemplateFile" -ForegroundColor Red
    Write-Host "Please create the deployment folder and files first." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $ParametersFile)) {
    Write-Host "Parameters file not found: $ParametersFile" -ForegroundColor Red
    Write-Host "Please create the parameters file first." -ForegroundColor Red
    exit 1
}

# Create resource group
Write-Host "Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
try {
    az group create --name $ResourceGroupName --location $Location --output none
    Write-Host "Resource group created successfully" -ForegroundColor Green
} catch {
    Write-Host "Failed to create resource group" -ForegroundColor Red
    exit 1
}

# Deploy template
Write-Host "Deploying infrastructure..." -ForegroundColor Yellow
try {
    az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file $TemplateFile `
        --parameters @$ParametersFile `
        --parameters projectName=$ProjectName `
        --parameters environment=$Environment `
        --parameters location=$Location `
        --parameters adminUsername=$AdminUsername `
        --parameters adminPassword=$AdminPassword `
        --parameters vmSize=$VmSize `
        --output none
    
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "Deployment failed" -ForegroundColor Red
    exit 1
}

# Get deployment outputs
Write-Host "Getting deployment outputs..." -ForegroundColor Yellow
try {
    $outputs = az deployment group show `
        --resource-group $ResourceGroupName `
        --name main `
        --query properties.outputs `
        --output json | ConvertFrom-Json
    
    Write-Host ""
    Write-Host "=== Deployment Outputs ===" -ForegroundColor Green
    Write-Host "VM Name: $($outputs.vmName.value)" -ForegroundColor Yellow
    Write-Host "Public IP: $($outputs.publicIpAddress.value)" -ForegroundColor Yellow
    Write-Host "Resource Group: $($outputs.resourceGroupName.value)" -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host "=== Connection Details ===" -ForegroundColor Green
    Write-Host "Username: $AdminUsername" -ForegroundColor Yellow
    Write-Host "Password: $AdminPassword" -ForegroundColor Yellow
    Write-Host "RDP to: $($outputs.publicIpAddress.value)" -ForegroundColor Yellow
    
} catch {
    Write-Host "Failed to get deployment outputs" -ForegroundColor Red
}

Write-Host ""
Write-Host "Deployment completed successfully!" -ForegroundColor Green 