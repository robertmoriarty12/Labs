# Azure App Service Demo - WAF & Private Endpoint Testing

This project demonstrates Azure App Service integration with Web Application Firewall (WAF) and Private Endpoints for Key Vault access. It's designed as a simple lab environment to showcase security features and network isolation.

## 🎯 Project Overview

This demo application provides:
- **Simple Web Interface**: A text input box for user interaction
- **Key Vault Integration**: Retrieves secrets using managed identity
- **WAF Protection**: Application Gateway with Web Application Firewall
- **Private Endpoint**: Secure Key Vault access through private networking
- **Managed Identity**: No secrets stored in application code

## 🏗️ Architecture

```
Internet → Application Gateway (WAF) → App Service → Key Vault (Private Endpoint)
```

### Components:
- **App Service**: Node.js application with managed identity
- **Key Vault**: Stores demo secret with private endpoint
- **Application Gateway**: WAF-enabled gateway for traffic filtering
- **Virtual Network**: Isolated network environment
- **Private Endpoint**: Secure Key Vault connectivity

## 🚀 Quick Start

### Prerequisites
- Azure CLI installed and configured
- PowerShell (for deployment script)
- Azure subscription with appropriate permissions

### Deployment

1. **Clone and Navigate**:
   ```bash
   git clone <your-repo-url>
   cd AppService-Demo
   ```

2. **Deploy Infrastructure**:
   ```powershell
   cd infrastructure
   .\deploy.ps1
   ```

3. **Access Application**:
   - Direct App Service URL: `https://<app-name>.azurewebsites.net`
   - Through Application Gateway: `http://<gateway-ip>`

## 🧪 Testing the Application

### Basic Functionality
1. Open the application URL
2. Enter any text in the input box
3. Click "Check Input"
4. Verify the response

### Key Vault Integration
1. Enter `secret` in the input box
2. Click "Check Input"
3. The application will retrieve and display the secret value from Key Vault

### WAF Testing
Try these malicious requests to test WAF protection:
```bash
# SQL Injection attempt
curl "http://<gateway-ip>/?id=1' OR '1'='1"

# XSS attempt
curl "http://<gateway-ip>/?search=<script>alert('xss')</script>"

# Path traversal attempt
curl "http://<gateway-ip>/../../../etc/passwd"
```

## 🔧 Configuration

### Environment Variables
- `KEY_VAULT_URL`: Key Vault endpoint URL
- `WEBSITE_NODE_DEFAULT_VERSION`: Node.js version (18-lts)

### Key Vault Secret
- **Name**: `demo-secret`
- **Value**: `This is a secret value from Azure Key Vault! 🔐`

### Managed Identity Permissions
The App Service managed identity has the following Key Vault permissions:
- `secrets/get`
- `secrets/list`

## 📁 Project Structure

```
AppService-Demo/
├── package.json              # Node.js dependencies
├── server.js                 # Express.js application
├── public/
│   └── index.html           # Frontend interface
├── infrastructure/
│   ├── main.bicep           # Infrastructure as Code
│   ├── parameters.json      # Deployment parameters
│   └── deploy.ps1           # Deployment script
└── README.md                # This file
```

## 🔒 Security Features

### Web Application Firewall (WAF)
- **Mode**: Prevention
- **Rule Set**: OWASP 3.2 + Microsoft Bot Manager
- **Protection**: SQL injection, XSS, path traversal, and more

### Private Endpoint
- **Key Vault**: Accessible only through private network
- **DNS**: Private DNS zone for vault resolution
- **Network**: Isolated subnet configuration

### Managed Identity
- **Authentication**: No secrets in application code
- **Authorization**: RBAC-based Key Vault access
- **Rotation**: Automatic credential management

## 🛠️ Customization

### Changing the Secret
1. Update the secret value in `infrastructure/main.bicep`:
   ```bicep
   resource demoSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
     parent: keyVault
     name: 'demo-secret'
     properties: {
       value: 'Your custom secret value here!'
       contentType: 'text/plain'
     }
   }
   ```

### Modifying WAF Rules
Edit the WAF policy in `infrastructure/main.bicep`:
```bicep
resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2023-05-01' = {
  // ... existing configuration ...
  properties: {
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
          ruleGroupOverrides: [
            // Add custom rule overrides here
          ]
        }
      ]
    }
  }
}
```

## 🧹 Cleanup

To remove all resources:
```powershell
az group delete --name rg-appservice-demo --yes --no-wait
```

## 📊 Monitoring

### Application Insights
Consider adding Application Insights for monitoring:
```bicep
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${namePrefix}-ai-${environment}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}
```

### Log Analytics
Monitor WAF logs and Key Vault access patterns through Azure Monitor.

## 🐛 Troubleshooting

### Common Issues

1. **Key Vault Access Denied**
   - Verify managed identity permissions
   - Check Key Vault access policies
   - Ensure private endpoint is configured

2. **WAF Blocking Legitimate Requests**
   - Review WAF logs in Application Gateway
   - Adjust rule exclusions if needed
   - Check OWASP rule set version

3. **Application Not Starting**
   - Verify Node.js version compatibility
   - Check application logs in App Service
   - Ensure all dependencies are installed

### Debug Commands
```bash
# Check App Service logs
az webapp log tail --name <app-name> --resource-group rg-appservice-demo

# Test Key Vault access
az keyvault secret show --vault-name <vault-name> --name demo-secret

# Check Application Gateway health
az network application-gateway show --name <gateway-name> --resource-group rg-appservice-demo
```

## 📚 Additional Resources

- [Azure App Service Documentation](https://docs.microsoft.com/en-us/azure/app-service/)
- [Azure Key Vault Documentation](https://docs.microsoft.com/en-us/azure/key-vault/)
- [Application Gateway WAF](https://docs.microsoft.com/en-us/azure/web-application-firewall/)
- [Private Endpoints](https://docs.microsoft.com/en-us/azure/private-link/)
- [Managed Identities](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Happy Testing! 🎯**
