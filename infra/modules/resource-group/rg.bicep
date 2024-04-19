targetScope = 'subscription'
param location string = deployment().location
param rgName string
@description('Tags to add to the resources')
param tags object
resource rg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  location: location
  name: rgName
  tags: tags
}
output rgId string = rg.id
output rgName string = rg.name
