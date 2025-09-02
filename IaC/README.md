# Enterprise-Grade Modular IaC with Bicep

This repository contains a modular, enterprise-grade Infrastructure as Code solution for Azure using Bicep templates. The structure is designed for scalability, reusability, and maintainability.

## 🏗️ Architecture Overview

```
IaC/
├── modules/                    # Reusable infrastructure modules
│   ├── network/
│   │   ├── vnet.bicep         # Virtual Network module
│   │   ├── nsg.bicep          # Network Security Group module
│   │   ├── publicip.bicep     # Public IP module
│   │   └── nic.bicep          # Network Interface module
│   └── compute/
│       └── vm.bicep           # Virtual Machine module
├── deployments/               # Project-specific deployments
│   └── sample-vm/            # Sample VM deployment
│       ├── main.bicep        # Main deployment template
│       └── parameters.json   # Parameters file
├── scripts/                  # Deployment scripts
│   ├── deploy.ps1           # PowerShell deployment script
│   └── deploy.sh            # Bash deployment script
└── README.md                # This file
```

## 🎯 Golden Templates

### Network Modules

#### `modules/network/vnet.bicep`
- **Purpose**: Deploy Virtual Networks with configurable subnets
- **Parameters**: name, location, addressPrefixes, subnets, tags
- **Outputs**: vnetId, vnetName, subnetIds, subnetNames

#### `modules/network/nsg.bicep`
- **Purpose**: Deploy Network Security Groups with configurable rules
- **Parameters**: name, location, securityRules, tags
- **Outputs**: nsgId, nsgName

#### `modules/network/publicip.bicep`
- **Purpose**: Deploy Public IP addresses
- **Parameters**: name, location, allocationMethod, sku, tags
- **Outputs**: publicIpId, publicIpName, publicIpAddress

#### `modules/network/nic.bicep`
- **Purpose**: Deploy Network Interfaces with optional public IP
- **Parameters**: name, location, subnetId, nsgId, publicIpId, tags
- **Outputs**: nicId, nicName

### Compute Modules

#### `modules/compute/vm.bicep`
- **Purpose**: Deploy Virtual Machines with configurable specs
- **Parameters**: name, location, adminUsername, adminPassword, nicId, vmSize, imagePublisher, imageOffer, imageSku, imageVersion, tags
- **Outputs**: vmId, vmName

## 🚀 Quick Start

### Prerequisites
- Azure CLI installed
- Azure subscription with appropriate permissions
- Bicep CLI (optional, handled by Azure CLI)

### Manual Deployment

```bash
# 1. Login to Azure
az login

# 2. Create resource group
az group create --name sample-vm-dev-rg --location eastus

# 3. Deploy the template
az deployment group create \
  --resource-group sample-vm-dev-rg \
  --template-file deployments/sample-vm/main.bicep \
  --parameters @deployments/sample-vm/parameters.json

# 4. Get deployment outputs
az deployment group show \
  --resource-group sample-vm-dev-rg \
  --name main \
  --query properties.outputs
```

### Using PowerShell Script

```powershell
# Run the PowerShell deployment script
.\scripts\deploy.ps1 -ProjectName "my-project" -Environment "dev" -Location "eastus"
```

### Using Bash Script

```bash
# Run the Bash deployment script
./scripts/deploy.sh my-project dev eastus
```

## 📋 Sample Deployment

The `deployments/sample-vm/` folder contains a complete example that deploys:

- **Virtual Network**: 10.0.0.0/16 with default subnet (10.0.0.0/24)
- **Network Security Group**: Allows RDP access from Internet
- **Public IP**: Static allocation for VM access
- **Network Interface**: Connected to VNet, NSG, and Public IP
- **Virtual Machine**: Windows Server 2019 with all networking configured

## 🏷️ Tagging Strategy

All resources are tagged with:
- **Project**: Project identifier
- **Environment**: dev/test/prod
- **Owner**: IaC
- **Purpose**: Specific purpose (e.g., SampleVM)

## 🔧 Creating New Deployments

1. **Create a new folder** under `deployments/`
2. **Copy the sample structure** from `deployments/sample-vm/`
3. **Modify the main.bicep** to use the modules you need
4. **Update parameters.json** with your specific values
5. **Deploy using the scripts** or manual commands

### Example: Multi-VM Deployment

```bicep
// Use the same modules for multiple VMs
module vm1 '../modules/compute/vm.bicep' = {
  name: '${resourcePrefix}-vm1'
  params: {
    name: '${resourcePrefix}-vm1'
    location: location
    adminUsername: adminUsername
    adminPassword: adminPassword
    nicId: nic1.outputs.nicId
    vmSize: 'Standard_D2s_v3'
    tags: tags
  }
}

module vm2 '../modules/compute/vm.bicep' = {
  name: '${resourcePrefix}-vm2'
  params: {
    name: '${resourcePrefix}-vm2'
    location: location
    adminUsername: adminUsername
    adminPassword: adminPassword
    nicId: nic2.outputs.nicId
    vmSize: 'Standard_D4s_v3'
    tags: tags
  }
}
```

## 🔒 Security Considerations

### Current Configuration
- RDP access allowed from Internet (for lab purposes)
- Standard SKU Public IPs
- Basic NSG rules

### Production Recommendations
1. **Restrict RDP access** to specific IP ranges
2. **Use Azure Bastion** for secure VM access
3. **Implement Azure Firewall** for advanced network security
4. **Enable Azure Security Center** monitoring
5. **Use Key Vault** for credential management

## 🐛 Troubleshooting

### Common Issues

1. **Module not found errors**:
   - Ensure relative paths in module references are correct
   - Check that all referenced modules exist

2. **Parameter validation errors**:
   - Verify all required parameters are provided
   - Check parameter types and constraints

3. **Resource naming conflicts**:
   - Ensure unique resource names across deployments
   - Use the resourcePrefix variable consistently

### Debug Commands

```bash
# Validate Bicep template
az bicep build --file deployments/sample-vm/main.bicep

# What-if analysis
az deployment group what-if \
  --resource-group sample-vm-dev-rg \
  --template-file deployments/sample-vm/main.bicep \
  --parameters @deployments/sample-vm/parameters.json

# Check deployment status
az deployment group show \
  --resource-group sample-vm-dev-rg \
  --name main
```

## 🔄 CI/CD Integration

### GitHub Actions
Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy IaC
on:
  workflow_dispatch:
    inputs:
      project:
        description: 'Project name'
        required: true
      environment:
        description: 'Environment'
        required: true
        default: 'dev'
      location:
        description: 'Azure region'
        required: true
        default: 'eastus'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      - run: |
          RG_NAME="${{ github.event.inputs.project }}-${{ github.event.inputs.environment }}-rg"
          az group create --name $RG_NAME --location ${{ github.event.inputs.location }}
          az deployment group create \
            --resource-group $RG_NAME \
            --template-file deployments/${{ github.event.inputs.project }}/main.bicep \
            --parameters @deployments/${{ github.event.inputs.project }}/parameters.json
```

### Azure DevOps
Create `azure-pipelines.yml`:

```yaml
trigger:
  branches:
    include:
    - main

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: AzureCLI@2
  inputs:
    azureSubscription: 'Your-Azure-Subscription'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      az group create --name $(projectName)-$(environment)-rg --location $(location)
      az deployment group create \
        --resource-group $(projectName)-$(environment)-rg \
        --template-file deployments/$(projectName)/main.bicep \
        --parameters @deployments/$(projectName)/parameters.json
```

## 📞 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Azure Bicep documentation
3. Check deployment logs for detailed error messages

## 🔄 Version History

- **v1.0**: Initial modular structure with golden templates
- **v1.1**: Added comprehensive documentation and deployment scripts 