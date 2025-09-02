@description('Name of the Public IP')
param name string

@description('Location of the Public IP')
param location string

@description('Allocation method for the Public IP')
param allocationMethod string = 'Static'

@description('SKU for the Public IP')
param sku string = 'Standard'

@description('Tags to apply to the Public IP')
param tags object = {}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    publicIPAllocationMethod: allocationMethod
  }
}

output publicIpId string = publicIp.id
output publicIpName string = publicIp.name
output publicIpAddress string = publicIp.properties.ipAddress 