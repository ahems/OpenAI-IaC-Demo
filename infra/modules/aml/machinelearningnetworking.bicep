// Creates private endpoints and DNS zones for the azure machine learning workspace
@description('Azure region of the deployment')
param location string

@description('Machine learning workspace private link endpoint name')
param machineLearningPleName string

@description('Resource ID of the subnet resource')
param subnetId string

@description('Resource ID of the machine learning workspace')
param workspaceArmId string

@description('Tags to add to the resources')
param tags object

var privateDnsZoneName = 'privatelink.api.azureml.ms'
var privateAznbDnsZoneName = 'privatelink.notebooks.azure.net'

/*.workspace.<region the workspace was created in>.api.azureml.ms
.workspace.<region the workspace was created in>.cert.api.azureml.ms
.<region the workspace was created in>.instances.azureml.ms
<region>.notebooks.azure.net
.<region>.inference.ml.azure.com

.workspace.<region the workspace was created in>.privatelink.api.azureml.ms
.<region>.privatelink.notebooks.azure.net
.inference.<region>.privatelink.api.azureml.ms
*/

resource machineLearningPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: machineLearningPleName
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: machineLearningPleName
        properties: {
          groupIds: [
            'amlworkspace'
          ]
          privateLinkServiceId: workspaceArmId
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

resource amlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
}

// Notebook
resource notebookPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateAznbDnsZoneName
  location: 'global'
}

resource privateEndpointDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
  parent: machineLearningPrivateEndpoint
  name: 'amlworkspace-PrivateDnsZoneGroup'
  properties:{
    privateDnsZoneConfigs: [
      {
        name: privateDnsZoneName
        properties:{
          privateDnsZoneId: amlPrivateDnsZone.id
        }
      }
      {
        name: privateAznbDnsZoneName
        properties:{
          privateDnsZoneId: notebookPrivateDnsZone.id
        }
      }
    ]
  }
}

output notebookPrivateDnsZoneName string = notebookPrivateDnsZone.name
output amlPrivateDnsZoneName string = amlPrivateDnsZone.name
