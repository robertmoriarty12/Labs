# Quick Start Guide

This guide will help you get the Flask app running quickly on your local machine.

## Prerequisites

- Python 3.11+
- Azure CLI (for Azure Key Vault access)

## Step 1: Install Dependencies

```bash
pip install -r requirements.txt
```

## Step 2: Set Up Azure Key Vault (Optional for Local Testing)

If you want to test the Azure Key Vault integration:

1. **Create a Key Vault:**
   ```bash
   az keyvault create --name your-keyvault-name --resource-group your-resource-group --location eastus
   ```

2. **Add a secret:**
   ```bash
   az keyvault secret set --vault-name your-keyvault-name --name success-code --value "your-secret-value"
   ```

3. **Set environment variables:**
   ```bash
   export AZURE_KEY_VAULT_URL="https://your-keyvault-name.vault.azure.net/"
   export SECRET_NAME="success-code"
   ```

## Step 3: Run the Application

```bash
python app.py
```

The application will start on `http://localhost:80`

## Step 4: Test the Endpoints

### Option 1: Use the test script
```bash
python test_local.py
```

### Option 2: Manual testing with curl
```bash
# Health check
curl http://localhost:80/

# Get secret (requires Azure Key Vault setup)
curl http://localhost:80/api/secret

# Status check
curl http://localhost:80/api/status
```

### Option 3: Use a web browser
- Health check: http://localhost:80/
- Get secret: http://localhost:80/api/secret
- Status: http://localhost:80/api/status

## Expected Responses

### Health Check (`/`)
```json
{
  "status": "healthy",
  "message": "Flask app is running successfully"
}
```

### Success Response (`/api/secret`)
```json
{
  "status": "success",
  "message": "You are successful - here's the code.",
  "code": "your-secret-value"
}
```

### Failure Response (if Key Vault is not accessible)
```json
{
  "status": "failure",
  "message": "Failed to retrieve secret from Azure Key Vault",
  "error": "Secret not found or access denied"
}
```

## Troubleshooting

### Port 80 Already in Use
If port 80 is already in use, you can change it:
```bash
export PORT=8080
python app.py
```

### Azure Authentication Issues
Make sure you're logged in to Azure CLI:
```bash
az login
```

### Key Vault Access Issues
- Verify the Key Vault URL is correct
- Ensure your Azure account has access to the Key Vault
- Check that the secret name exists in the Key Vault

## Next Steps

Once you have the local version working, you can:

1. **Build and test with Docker:**
   ```bash
   docker build -t flask-app:latest .
   docker run -p 80:80 flask-app:latest
   ```

2. **Deploy to AKS:**
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

3. **Read the full README.md** for detailed deployment instructions.
