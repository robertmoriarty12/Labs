@description('Name of the Network Security Group')
param name string

@description('Location of the NSG')
param location string

@description('Array of security rules')
param securityRules array

@description('Tags to apply to the NSG')
param tags object = {}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    securityRules: [
      for rule in securityRules: {
        name: rule.name
        properties: {
          priority: rule.priority
          access: rule.access
          direction: rule.direction
          protocol: rule.protocol
          sourceAddressPrefix: rule.sourceAddressPrefix
          destinationAddressPrefix: rule.destinationAddressPrefix
          destinationPortRange: rule.destinationPortRange
        }
      }
    ]
  }
}

output nsgId string = nsg.id
output nsgName string = nsg.name 