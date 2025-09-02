@description('Name of the Virtual Network')
param name string

@description('Location of the Virtual Network')
param location string

@description('Address prefixes for the VNet')
param addressPrefixes array

@description('Array of subnets with name and addressPrefix')
param subnets array

@description('Tags to apply to the VNet')
param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: [
      for subnet in subnets: {
        name: subnet.name
        properties: {
          addressPrefix: subnet.addressPrefix
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output subnetIds array = [for (subnet, i) in subnets: '${vnet.id}/subnets/${subnet.name}']
output subnetNames array = [for subnet in subnets: subnet.name] 