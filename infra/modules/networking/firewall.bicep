param fwname string
param fwipConfigurations array
param fwipManagementConfigurations object
param location string = resourceGroup().location
param availabilityZones array = ['1', '2', '3']

resource firewall 'Microsoft.Network/azureFirewalls@2022-01-01' = {
  name: fwname
  location: location
  zones: !empty(availabilityZones) ? availabilityZones : null
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Basic'
    }
    ipConfigurations: fwipConfigurations
    managementIpConfiguration: fwipManagementConfigurations
    additionalProperties: {
      'Network.DNS.EnableProxy': 'True'
    }
  }
}
output fwPrivateIP string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output fwName string = firewall.name
