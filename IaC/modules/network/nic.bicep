@description('Name of the Network Interface')
param name string

@description('Location of the Network Interface')
param location string

@description('Subnet ID for the NIC')
param subnetId string

@description('NSG ID for the NIC')
param nsgId string

@description('Public IP ID for the NIC (optional)')
param publicIpId string = ''

@description('Tags to apply to the NIC')
param tags object = {}

resource nic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: !empty(publicIpId) ? {
            id: publicIpId
          } : null
        }
      }
    ]
    networkSecurityGroup: {
      id: nsgId
    }
  }
}

output nicId string = nic.id
output nicName string = nic.name 