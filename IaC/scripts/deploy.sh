#!/bin/bash

# Enterprise IaC Deployment Script
# Usage: ./deploy.sh <project-name> <environment> <location> [admin-username] [admin-password] [vm-size]

set -e

# Check if required arguments are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <project-name> <environment> <location> [admin-username] [admin-password] [vm-size]"
    echo "Example: $0 my-project dev eastus"
    exit 1
fi

PROJECT_NAME=$1
ENVIRONMENT=$2
LOCATION=$3
ADMIN_USERNAME=${4:-"adminuser"}
ADMIN_PASSWORD=${5:-"P@ssword123!"}
VM_SIZE=${6:-"Standard_D2s_v3"}

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|test|prod)$ ]]; then
    echo "Error: Environment must be dev, test, or prod"
    exit 1
fi

echo "=== Enterprise IaC Deployment ==="
echo "Project: $PROJECT_NAME"
echo "Environment: $ENVIRONMENT"
echo "Location: $LOCATION"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI not found. Please install Azure CLI first."
    exit 1
fi

# Check Azure CLI version
AZ_VERSION=$(az version --query '"azure-cli"' -o tsv)
echo "Azure CLI version: $AZ_VERSION"

# Check if logged in
if ! az account show &> /dev/null; then
    echo "Error: Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

ACCOUNT_INFO=$(az account show --query '{name:user.name, subscription:name}' -o json)
ACCOUNT_NAME=$(echo $ACCOUNT_INFO | jq -r '.name')
SUBSCRIPTION_NAME=$(echo $ACCOUNT_INFO | jq -r '.subscription')

echo "Logged in as: $ACCOUNT_NAME"
echo "Subscription: $SUBSCRIPTION_NAME"
echo ""

# Set variables
RESOURCE_GROUP_NAME="$PROJECT_NAME-$ENVIRONMENT-rg"
TEMPLATE_FILE="deployments/$PROJECT_NAME/main.bicep"
PARAMETERS_FILE="deployments/$PROJECT_NAME/parameters.json"

# Check if template files exist
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file not found: $TEMPLATE_FILE"
    echo "Please create the deployment folder and files first."
    exit 1
fi

if [ ! -f "$PARAMETERS_FILE" ]; then
    echo "Error: Parameters file not found: $PARAMETERS_FILE"
    echo "Please create the parameters file first."
    exit 1
fi

# Create resource group
echo "Creating resource group: $RESOURCE_GROUP_NAME"
if az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION" --output none; then
    echo "Resource group created successfully"
else
    echo "Error: Failed to create resource group"
    exit 1
fi

# Deploy template
echo "Deploying infrastructure..."
if az deployment group create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file "$TEMPLATE_FILE" \
    --parameters @"$PARAMETERS_FILE" \
    --parameters projectName="$PROJECT_NAME" \
    --parameters environment="$ENVIRONMENT" \
    --parameters location="$LOCATION" \
    --parameters adminUsername="$ADMIN_USERNAME" \
    --parameters adminPassword="$ADMIN_PASSWORD" \
    --parameters vmSize="$VM_SIZE" \
    --output none; then
    
    echo "Deployment completed successfully!"
else
    echo "Error: Deployment failed"
    exit 1
fi

# Get deployment outputs
echo "Getting deployment outputs..."
if OUTPUTS=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name main \
    --query properties.outputs \
    --output json 2>/dev/null); then
    
    VM_NAME=$(echo $OUTPUTS | jq -r '.vmName.value')
    PUBLIC_IP=$(echo $OUTPUTS | jq -r '.publicIpAddress.value')
    RG_NAME=$(echo $OUTPUTS | jq -r '.resourceGroupName.value')
    
    echo ""
    echo "=== Deployment Outputs ==="
    echo "VM Name: $VM_NAME"
    echo "Public IP: $PUBLIC_IP"
    echo "Resource Group: $RG_NAME"
    
    echo ""
    echo "=== Connection Details ==="
    echo "Username: $ADMIN_USERNAME"
    echo "Password: $ADMIN_PASSWORD"
    echo "RDP to: $PUBLIC_IP"
else
    echo "Warning: Failed to get deployment outputs"
fi

echo ""
echo "Deployment completed successfully!" 