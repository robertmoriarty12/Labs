@description('Name of the Virtual Machine')
param name string

@description('Location of the Virtual Machine')
param location string

@description('Admin username')
param adminUsername string

@description('Admin password')
@secure()
param adminPassword string

@description('Network Interface ID')
param nicId string

@description('VM Size')
param vmSize string = 'Standard_D2s_v3'

@description('Image Publisher')
param imagePublisher string = 'MicrosoftWindowsServer'

@description('Image Offer')
param imageOffer string = 'WindowsServer'

@description('Image SKU')
param imageSku string = '2019-Datacenter'

@description('Image Version')
param imageVersion string = 'latest'

@description('Tags to apply to the VM')
param tags object = {}

resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: name
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicId
        }
      ]
    }
  }
}

output vmId string = vm.id
output vmName string = vm.name 