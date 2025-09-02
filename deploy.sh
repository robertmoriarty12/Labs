#!/bin/bash

# Flask App AKS Deployment Script
# This script helps deploy the Flask app to Azure Kubernetes Service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ACR_NAME=""
RESOURCE_GROUP=""
AKS_CLUSTER_NAME=""
KEY_VAULT_NAME=""
IMAGE_NAME="flask-app"
IMAGE_TAG="latest"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists az; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! command_exists kubectl; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    if ! command_exists docker; then
        print_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    print_status "All prerequisites are satisfied."
}

# Function to get configuration from user
get_configuration() {
    print_status "Please provide the following configuration:"
    
    read -p "Azure Container Registry name: " ACR_NAME
    read -p "Resource Group name: " RESOURCE_GROUP
    read -p "AKS Cluster name: " AKS_CLUSTER_NAME
    read -p "Azure Key Vault name: " KEY_VAULT_NAME
    
    # Validate inputs
    if [ -z "$ACR_NAME" ] || [ -z "$RESOURCE_GROUP" ] || [ -z "$AKS_CLUSTER_NAME" ] || [ -z "$KEY_VAULT_NAME" ]; then
        print_error "All fields are required."
        exit 1
    fi
}

# Function to build and push Docker image
build_and_push_image() {
    print_status "Building Docker image..."
    docker build -t $IMAGE_NAME:$IMAGE_TAG .
    
    print_status "Tagging image for ACR..."
    docker tag $IMAGE_NAME:$IMAGE_TAG $ACR_NAME.azurecr.io/$IMAGE_NAME:$IMAGE_TAG
    
    print_status "Pushing image to ACR..."
    az acr login --name $ACR_NAME
    docker push $ACR_NAME.azurecr.io/$IMAGE_NAME:$IMAGE_TAG
    
    print_status "Image pushed successfully."
}

# Function to update Kubernetes manifests
update_manifests() {
    print_status "Updating Kubernetes manifests..."
    
    # Update deployment.yaml with ACR image and Key Vault URL
    sed -i.bak "s|flask-app:latest|$ACR_NAME.azurecr.io/$IMAGE_NAME:$IMAGE_TAG|g" k8s/deployment.yaml
    sed -i.bak "s|https://your-keyvault-name.vault.azure.net/|https://$KEY_VAULT_NAME.vault.azure.net/|g" k8s/deployment.yaml
    
    print_status "Manifests updated successfully."
}

# Function to deploy to AKS
deploy_to_aks() {
    print_status "Getting AKS credentials..."
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --overwrite-existing
    
    print_status "Deploying to AKS..."
    kubectl apply -f k8s/namespace.yaml
    kubectl apply -f k8s/service-account.yaml
    kubectl apply -f k8s/deployment.yaml
    kubectl apply -f k8s/service.yaml
    
    print_status "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/flask-app -n flask-app
    
    print_status "Deployment completed successfully!"
}

# Function to show deployment status
show_status() {
    print_status "Deployment Status:"
    echo ""
    kubectl get pods -n flask-app
    echo ""
    kubectl get services -n flask-app
    echo ""
    
    # Get the external IP
    EXTERNAL_IP=$(kubectl get service flask-app-service -n flask-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
    
    if [ "$EXTERNAL_IP" != "Pending" ] && [ "$EXTERNAL_IP" != "" ]; then
        print_status "Application is accessible at: http://$EXTERNAL_IP"
        print_status "Test endpoints:"
        echo "  Health check: http://$EXTERNAL_IP/"
        echo "  Get secret: http://$EXTERNAL_IP/api/secret"
        echo "  Status: http://$EXTERNAL_IP/api/status"
    else
        print_warning "External IP is still pending. Please wait a few minutes and check again."
    fi
}

# Function to clean up
cleanup() {
    print_status "Cleaning up temporary files..."
    rm -f k8s/deployment.yaml.bak
}

# Main execution
main() {
    echo "Flask App AKS Deployment Script"
    echo "================================"
    echo ""
    
    check_prerequisites
    get_configuration
    
    echo ""
    print_status "Starting deployment process..."
    
    build_and_push_image
    update_manifests
    deploy_to_aks
    show_status
    cleanup
    
    echo ""
    print_status "Deployment completed! 🎉"
    print_warning "Remember to configure Azure Workload Identity for Key Vault access."
}

# Handle script interruption
trap cleanup EXIT

# Run main function
main "$@"
