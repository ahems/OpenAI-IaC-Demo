targetScope = 'subscription'

// Parameters
param rgName string
param vnetHubName string
param vnetName string = 'VNet-HUB'
param vnetVMSubnetName string = 'VM-Subnet'
param vmSize string = 'Standard_B2ms'
param virtualMachineName string = 'jumpbox'
param hubVNETaddPrefixes array
param hubSubnets array
param azfwName string
param rtVMSubnetName string
param location string = deployment().location
param availabilityZones array = ['1', '2', '3']
param adminUsername string = 'azureuser'
var tags = { }

@secure()
param adminPassword string

module rg 'modules/resource-group/rg.bicep' = {
  name: rgName
  params: {
    rgName: rgName
    location: location
    tags:tags
  }
}

module vnethub 'modules/networking/hubvnet.bicep' = {
  scope: resourceGroup(rg.name)
  name: vnetHubName
  params: {
    location: location
    vnetAddressSpace: {
      addressPrefixes: hubVNETaddPrefixes
    }
    vnetName: vnetHubName
    subnets: hubSubnets
  }
  dependsOn: [
    rg
  ]
}

module publicipfw 'modules/networking/publicip.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'AZFW-PIP'
  params: {
    availabilityZones: availabilityZones
    location: location
    publicipName: 'AZFW-PIP'
    publicipproperties: {
      publicIPAllocationMethod: 'Static'
    }
    publicipsku: {
      name: 'Standard'
      tier: 'Regional'
    }
  }
  dependsOn: [
    rg
  ]
}

module publicipfwmanagement 'modules/networking/publicip.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'AZFW-Management-PIP'
  params: {
    availabilityZones:availabilityZones
    location: location
    publicipName: 'AZFW-Management-PIP'
    publicipproperties: {
      publicIPAllocationMethod: 'Static'
    }
    publicipsku: {
      name: 'Standard'
      tier: 'Regional'
    }
  }
  dependsOn: [
    rg
  ]
}

resource subnetfw 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  scope: resourceGroup(rg.name)
  name: '${vnethub.name}/AzureFirewallSubnet'
}

resource subnetfwmanagement 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  scope: resourceGroup(rg.name)
  name: '${vnethub.name}/AzureFirewallManagementSubnet'
}

module azfirewall 'modules/networking/firewall.bicep' = {
  scope: resourceGroup(rg.name)
  name: azfwName
  params: {
    availabilityZones: availabilityZones
    location: location
    fwname: azfwName
    fwipConfigurations: [
      {
        name: 'AZFW-PIP'
        properties: {
          subnet: {
            id: subnetfw.id
          }
          publicIPAddress: {
            id: publicipfw.outputs.publicipId
          }
        }
      }
    ]
    fwipManagementConfigurations: {
      name: 'AZFW-Management-PIP'
      properties: {
        subnet: {
          id: subnetfwmanagement.id
        }
        publicIPAddress: {
          id: publicipfwmanagement.outputs.publicipId
        }
      }
    }
  }
  dependsOn: [
    rg
  ]
}

module publicipbastion 'modules/networking/publicip.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'publicipbastion'
  params: {
    location: location
    publicipName: 'bastion-pip'
    publicipproperties: {
      publicIPAllocationMethod: 'Static'
    }
    publicipsku: {
      name: 'Standard'
      tier: 'Regional'
    }
  }
  dependsOn: [
    rg
  ]
}

resource subnetbastion 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  scope: resourceGroup(rg.name)
  name: '${vnethub.name}/AzureBastionSubnet'
}

module bastion 'modules/networking/bastion.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'bastion'
  params: {
    location: location
    bastionpipId: publicipbastion.outputs.publicipId
    subnetId: subnetbastion.id
  }
  dependsOn: [
    rg
  ]
}

resource subnetVM 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  scope: resourceGroup(rgName)
  name: '${vnetName}/${vnetVMSubnetName}'
}

module nsg 'modules/networking/nsg.bicep' = {
  scope: resourceGroup(rgName)
  name: 'jumpbox-nsg'
  params: {
    location: location
    nsgName: 'jumpbox-nsg'
  }
  dependsOn: [
    rg
  ]
}

module jumpbox 'modules/vm/dsvmjumpbox.bicep' = {
  scope: resourceGroup(rgName)
  name: 'jumpbox'
  params: {
    networkSecurityGroupId: nsg.outputs.networkSecurityGroup
    virtualMachineName: virtualMachineName
    location: location
    subnetId: subnetVM.id
    vmSizeParameter: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
  dependsOn: [
    rg
  ]
}

module routetable 'modules/networking/routetable.bicep' = {
  scope: resourceGroup(rg.name)
  name: rtVMSubnetName
  params: {
    location: location
    rtName: rtVMSubnetName
  }
  dependsOn: [
    rg
  ]
}

module routetableroutes 'modules/networking/routetableroutes.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'vm-to-internet'
  params: {
    routetableName: routetable.name
    routeName: 'vm-to-internet'
    properties: {
      nextHopType: 'VirtualAppliance'
      nextHopIpAddress: azfirewall.outputs.fwPrivateIP
      addressPrefix: '0.0.0.0/0'
    }
  }
  dependsOn: [
    rg
  ]
}
