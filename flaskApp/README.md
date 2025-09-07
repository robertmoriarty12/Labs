# Flask App with Azure Key Vault Integration

This project demonstrates a Flask application that retrieves secrets from Azure Key Vault and is deployed to Azure Kubernetes Service (AKS) using Workload Identity for secure authentication.

## 🎯 **Project Status: SUCCESSFULLY DEPLOYED**

- ✅ **Flask application** running on AKS
- ✅ **Azure Key Vault integration** working with Workload Identity
- ✅ **Secure secret retrieval** without storing credentials
- ✅ **External access** via Load Balancer
- ✅ **Health checks** and monitoring endpoints

## 🌐 **Live Application**

- **External IP**: `http://128.203.232.255`
- **Health Check**: `GET /` → `{"status": "healthy"}`
- **Secret Endpoint**: `GET /api/secret` → `{"code": "SUCCESS-CODE-7245", "message": "You are successful - here's the code.", "status": "success"}`
- **Status Check**: `GET /api/status` → Application status

## Features

- Flask web application listening on port 8080 (container) / 80 (external)
- Azure Key Vault integration using Workload Identity
- Kubernetes deployment ready for AKS
- Health check endpoints
- Success/failure response handling
- Secure authentication without stored credentials
- Comprehensive logging and error handling

## Project Structure

```
flaskApp/
├── app.py                 # Main Flask application
├── requirements.txt       # Python dependencies
├── Dockerfile            # Container configuration
├── k8s/                  # Kubernetes manifests
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── service-account.yaml
├── deploy_simple.ps1     # Automated deployment script
├── test_local.py         # Local testing script
└── README.md             # This file
```

## 🚀 **Quick Start**

### Prerequisites

- Python 3.11+
- Azure CLI (`az login`)
- kubectl
- Docker
- PowerShell (for Windows deployment)

### Automated Deployment

1. **Run the deployment script:**
   ```powershell
   .\deploy_simple.ps1
   ```

2. **Test the application:**
   ```bash
   curl http://<external-ip>/api/secret
   ```

## 🔧 **Manual Setup**

### Local Development

1. **Install Python dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Set environment variables:**
   ```bash
   export AZURE_KEY_VAULT_URL="https://your-keyvault-name.vault.azure.net/"
   export SECRET_NAME="success-code"
   ```

3. **Run the application locally:**
   ```bash
   python app.py
   ```

4. **Test the endpoints:**
   - Health check: `http://localhost:8080/`
   - Get secret: `http://localhost:8080/api/secret`
   - Status check: `http://localhost:8080/api/status`

### Azure Infrastructure Setup

#### 1. Create Azure Resources

```powershell
# Create resource group
az group create --name flask-app-rg --location centralus

# Create AKS cluster with Workload Identity enabled
az aks create --resource-group flask-app-rg --name flask-app-aks --node-count 1 --node-vm-size Standard_D2s_v5 --enable-oidc-issuer --enable-workload-identity

# Create Azure Container Registry
az acr create --resource-group flask-app-rg --name flaskappacr --sku Basic

# Create Key Vault
az keyvault create --name flaskkv --resource-group flask-app-rg --location centralus
```

#### 2. Configure Workload Identity

```powershell
# Create managed identity
az identity create --name flask-app-identity --resource-group flask-app-rg --location centralus

# Get identity details
$IDENTITY_CLIENT_ID=$(az identity show --name flask-app-identity --resource-group flask-app-rg --query clientId -o tsv)
$IDENTITY_TENANT_ID=$(az identity show --name flask-app-identity --resource-group flask-app-rg --query tenantId -o tsv)

# Grant Key Vault permissions
az keyvault set-policy --name flaskkv --secret-permissions get list --spn $IDENTITY_CLIENT_ID

# Get OIDC issuer URL
$OIDC_ISSUER=$(az aks show --resource-group flask-app-rg --name flask-app-aks --query oidcIssuerProfile.issuerUrl -o tsv)

# Create federated credential
az identity federated-credential create --name flask-app-federated-credential --identity-name flask-app-identity --resource-group flask-app-rg --issuer $OIDC_ISSUER --subject system:serviceaccount:flask-app:flask-app-sa --audience api://AzureADTokenExchange
```

#### 3. Build and Deploy

```powershell
# Build and push Docker image
az acr build --registry flaskappacr --image flask-app:latest .

# Deploy to AKS
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/service-account.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

## 🔐 **Workload Identity Configuration**

### Critical Components

1. **Service Account with Annotations:**
   ```yaml
   apiVersion: v1
   kind: ServiceAccount
   metadata:
     name: flask-app-sa
     namespace: flask-app
     annotations:
       azure.workload.identity/client-id: "your-managed-identity-client-id"
       azure.workload.identity/tenant-id: "your-tenant-id"
   ```

2. **Pod Template with Workload Identity Label:**
   ```yaml
   template:
     metadata:
       labels:
         app: flask-app
         azure.workload.identity/use: "true"  # CRITICAL: Triggers webhook
   ```

3. **Environment Variables:**
   ```yaml
   env:
   - name: AZURE_CLIENT_ID
     value: "your-managed-identity-client-id"
   - name: AZURE_TENANT_ID
     value: "your-tenant-id"
   - name: AZURE_KEY_VAULT_URL
     value: "https://your-keyvault.vault.azure.net/"
   ```

## 📋 **API Endpoints**

### Health Check
- **URL:** `GET /`
- **Response:** `{"status": "healthy"}`

### Get Secret
- **URL:** `GET /api/secret`
- **Response:** 
  ```json
  {
    "code": "SUCCESS-CODE-7245",
    "message": "You are successful - here's the code.",
    "status": "success"
  }
  ```

### Status Check
- **URL:** `GET /api/status`
- **Response:** Connection status to Azure Key Vault

## 🔧 **Environment Variables**

| Variable | Description | Default |
|----------|-------------|---------|
| `AZURE_KEY_VAULT_URL` | Azure Key Vault URL | Required |
| `SECRET_NAME` | Name of the secret in Key Vault | `success-code` |
| `PORT` | Port to run the Flask app on | `8080` |
| `AZURE_CLIENT_ID` | Managed Identity Client ID | Required for Workload Identity |
| `AZURE_TENANT_ID` | Azure Tenant ID | Required for Workload Identity |

## 🚨 **Troubleshooting**

### Common Issues and Solutions

1. **"Identity not found" error:**
   - Ensure `azure.workload.identity/use: "true"` label is present
   - Verify webhook is running: `kubectl get pods -n kube-system | findstr webhook`
   - Check service account annotations

2. **"Permission denied" on port 80:**
   - Use port 8080 for non-root containers
   - Update `targetPort` in service to 8080

3. **"Insufficient cpu" scheduling errors:**
   - Remove resource limits temporarily
   - Scale down replicas to 1

4. **"ImagePullBackOff" errors:**
   - Grant ACR permissions to AKS: `az role assignment create --assignee <aks-identity> --role AcrPull --scope <acr-id>`

5. **"Public network access is disabled" from Key Vault:**
   - Enable public access: `az keyvault update --name <keyvault> --public-network-access Enabled`

### Verification Commands

```powershell
# Check pod status
kubectl get pods -n flask-app

# Check service account
kubectl get serviceaccount flask-app-sa -n flask-app -o yaml

# Check webhook configuration
kubectl get mutatingwebhookconfigurations azure-wi-webhook-mutating-webhook-configuration -o yaml

# View application logs
kubectl logs -n flask-app -l app=flask-app --tail=30

# Test the application
curl http://<external-ip>/api/secret
```

## 🔒 **Security Features**

- ✅ **Workload Identity** for secure authentication
- ✅ **Non-root container** execution
- ✅ **Secret management** via Azure Key Vault
- ✅ **Network security** with proper port configuration
- ✅ **RBAC** for Key Vault access
- ✅ **No stored credentials** in application code

## 📊 **Infrastructure Details**

- **Resource Group**: `flask-app-rg-08251836`
- **AKS Cluster**: `flask-app-aks-08251836`
- **Container Registry**: `flaskappacr08251836.azurecr.io`
- **Key Vault**: `flaskkv08251836.vault.azure.net`
- **Managed Identity**: `flask-app-identity`
- **External IP**: `128.203.232.255`

## 🎯 **Key Success Factors**

1. **Workload Identity Label**: The `azure.workload.identity/use: "true"` label is critical
2. **Port Configuration**: Use 8080 internally, 80 externally
3. **Resource Limits**: Start without limits for testing
4. **Network Access**: Ensure Key Vault allows public access
5. **Federated Credentials**: Properly link managed identity to service account

## 📝 **Contributing**

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 **License**

This project is open source and available under the [MIT License](LICENSE).
