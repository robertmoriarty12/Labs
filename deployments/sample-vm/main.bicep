@description('Project name')
param projectName string

@description('Environment (dev, test, prod)')
param environment string

@description('Azure location')
param location string

@description('Admin username')
param adminUsername string

@description('Admin password')
@secure()
param adminPassword string

@description('VM size')
param vmSize string = 'Standard_D2s_v3'

var resourcePrefix = '${projectName}-${environment}'
var tags = {
  Project: projectName
  Environment: environment
  Owner: 'IaC'
  Purpose: 'SampleVM'
}

// Virtual Network
module vnet '../modules/network/vnet.bicep' = {
  name: '${resourcePrefix}-vnet'
  params: {
    name: '${resourcePrefix}-vnet'
    location: location
    addressPrefixes: [
      '10.0.0.0/16'
    ]
    subnets: [
      {
        name: 'default'
        addressPrefix: '10.0.0.0/24'
      }
    ]
    tags: tags
  }
}

// Network Security Group
module nsg '../modules/network/nsg.bicep' = {
  name: '${resourcePrefix}-nsg'
  params: {
    name: '${resourcePrefix}-nsg'
    location: location
    securityRules: [
      {
        name: 'AllowRDP'
        priority: 1000
        direction: 'Inbound'
        access: 'Allow'
        protocol: 'Tcp'
        sourceAddressPrefix: 'Internet'
        destinationAddressPrefix: '*'
        destinationPortRange: '3389'
      }
    ]
    tags: tags
  }
}

// Public IP
module publicIp '../modules/network/publicip.bicep' = {
  name: '${resourcePrefix}-pip'
  params: {
    name: '${resourcePrefix}-pip'
    location: location
    tags: tags
  }
}

// Network Interface
module nic '../modules/network/nic.bicep' = {
  name: '${resourcePrefix}-nic'
  params: {
    name: '${resourcePrefix}-nic'
    location: location
    subnetId: vnet.outputs.subnetIds[0]
    nsgId: nsg.outputs.nsgId
    publicIpId: publicIp.outputs.publicIpId
    tags: tags
  }
}

// Virtual Machine
module vm '../modules/compute/vm.bicep' = {
  name: '${resourcePrefix}-vm'
  params: {
    name: '${resourcePrefix}-vm'
    location: location
    adminUsername: adminUsername
    adminPassword: adminPassword
    nicId: nic.outputs.nicId
    vmSize: vmSize
    tags: tags
  }
}

// Outputs
output vmName string = vm.outputs.vmName
output publicIpAddress string = publicIp.outputs.publicIpAddress
output resourceGroupName string = resourceGroup().name 