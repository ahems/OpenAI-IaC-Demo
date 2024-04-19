targetScope = 'subscription'

// Parameters
@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string = uniqueString(utcNow('u'))
param rgName string
param vnetSpokeName string
param spokeVNETaddPrefixes array
param spokeSubnets array
param spokePVSubnetname string = 'servicespe'
param vnetHubName string
param vnetHUBRGName string
param dhcpOptions object = { dnsServers: ['10.0.1.4'] }
param location string = deployment().location
@allowed([ 'australiaeast','brazilsouth','westus','westus2','westeurope','northeurope','southeastasia','eastasia','westcentralus','southcentralus','eastus','eastus2','canadacentral','japaneast','centralindia','uksouth','japanwest','koreacentral','francecentral','northcentralus','centralus','southafricanorth','uaenorth','swedencentral','switzerlandnorth','switzerlandwest','germanywestcentral','norwayeast','westus3','jioindiawest','qatarcentral','canadaeast','polandcentral','southindia','italynorth' ])
param cognitiveservicesLocation string = location
param acrName string = 'acr-${environmentName}'
param keyvaultName string = 'kv-${substring(environmentName, 0, 21)}'
param machinellearningworkspacename string = 'aml-${environmentName}'
param cognitiveservicesname string = 'ai-${environmentName}'
param storageAccountName string = 'storage${substring(toLower(environmentName), 0, 16)}'
param storagePleBlobName string = 'pv-blob-${environmentName}'
param storagePleFileName string = 'pv-file-${environmentName}'
param workspaceComputeName string = 'compute-${substring(environmentName, 0, 16)}'
param keyVaultPrivateEndpointName string = 'pv-kv-${environmentName}'
param machineLearningPleName string = 'pv-ml-${environmentName}'
param acrPrivateEndpointName string = 'pv-acr-${environmentName}'
param applicationInsightsDashboardName string = 'app-insights-dash-${environmentName}'
param applicationInsightsName string = 'app-insights-${environmentName}'
param logAnalyticsName string = 'log-analytics-${environmentName}'
param amlComputeDefaultVmSize string = 'Standard_DS3_v2'
param userAssignedIdentityName string = 'amlIdentity-${environmentName}'
var tags = { 'azd-env-name': environmentName }
@allowed([ 'azure', 'openai', 'azure_custom' ])
param openAiHost string = 'azure'
param useGPT4V bool = false

param chatGptModelName string = ''
param chatGptDeploymentName string = ''
param chatGptDeploymentVersion string = ''
param chatGptDeploymentCapacity int = 0
var chatGpt = {
  modelName: !empty(chatGptModelName) ? chatGptModelName : startsWith(openAiHost, 'azure') ? 'gpt-35-turbo' : 'gpt-3.5-turbo'
  deploymentName: !empty(chatGptDeploymentName) ? chatGptDeploymentName : 'chat'
  deploymentVersion: !empty(chatGptDeploymentVersion) ? chatGptDeploymentVersion : '0613'
  deploymentCapacity: chatGptDeploymentCapacity != 0 ? chatGptDeploymentCapacity : 30
}

param embeddingModelName string = ''
param embeddingDeploymentName string = ''
param embeddingDeploymentVersion string = ''
param embeddingDeploymentCapacity int = 0
param embeddingDimensions int = 0
var embedding = {
  modelName: !empty(embeddingModelName) ? embeddingModelName : 'text-embedding-ada-002'
  deploymentName: !empty(embeddingDeploymentName) ? embeddingDeploymentName : 'embedding'
  deploymentVersion: !empty(embeddingDeploymentVersion) ? embeddingDeploymentVersion : '2'
  deploymentCapacity: embeddingDeploymentCapacity != 0 ? embeddingDeploymentCapacity : 30
  dimensions: embeddingDimensions != 0 ? embeddingDimensions : 1536
}

param gpt4vModelName string = 'gpt-4'
param gpt4vDeploymentName string = 'gpt-4v'
param gpt4vModelVersion string = 'vision-preview'
param gpt4vDeploymentCapacity int = 10

var defaultOpenAiDeployments = [
  {
    name: chatGpt.deploymentName
    model: {
      format: 'OpenAI'
      name: chatGpt.modelName
      version: chatGpt.deploymentVersion
    }
    sku: {
      name: 'Standard'
      capacity: chatGpt.deploymentCapacity
    }
  }
  {
    name: embedding.deploymentName
    model: {
      format: 'OpenAI'
      name: embedding.modelName
      version: embedding.deploymentVersion
    }
    sku: {
      name: 'Standard'
      capacity: embedding.deploymentCapacity
    }
  }
]

var openAiDeployments = concat(defaultOpenAiDeployments, useGPT4V ? [
    {
      name: gpt4vDeploymentName
      model: {
        format: 'OpenAI'
        name: gpt4vModelName
        version: gpt4vModelVersion
      }
      sku: {
        name: 'Standard'
        capacity: gpt4vDeploymentCapacity
      }
    }
  ] : [])

module rg 'modules/resource-group/rg.bicep' = {
  name: rgName
  params: {
    rgName: rgName
    location: location
    tags:tags
  }
}

module vnetspoke 'modules/networking/spokevnet.bicep' = {
  scope: resourceGroup(rg.name)
  name: vnetSpokeName
  params: {
    location: location
    vnetAddressSpace: {
      addressPrefixes: spokeVNETaddPrefixes
    }
    vnetName: vnetSpokeName
    subnets: spokeSubnets
    dhcpOptions: dhcpOptions
  }
  dependsOn: [
    rg
    contributorAccess
  ]
}

module mlnetworking 'modules/aml/machinelearningnetworking.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'Deploy-aml-networking'
  params: {
    location:location
    machineLearningPleName:machineLearningPleName
    subnetId: servicesSubnet.id
    tags: tags
    workspaceArmId:azuremlWorkspace.outputs.workspaceId
  }
  dependsOn: [
    vnetspoke
    azuremlWorkspace
  ]
}

resource vnethub 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  scope: resourceGroup(vnetHUBRGName)
  name: vnetHubName
}

module vnetpeeringhub 'modules/networking/vnetpeering.bicep' = {
  scope: resourceGroup(vnetHUBRGName)
  name: 'vnetpeeringhub'
  params: {
    peeringName: 'HUB-to-Spoke'
    vnetName: vnethub.name
    properties: {
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true
      remoteVirtualNetwork: {
        id: vnetspoke.outputs.vnetId
      }
    }
  }
  dependsOn: [
    vnethub
    vnetspoke
  ]
}

module vnetpeeringspoke 'modules/networking/vnetpeering.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'vnetpeeringspoke'
  params: {
    peeringName: 'Spoke-to-HUB'
    vnetName: vnetspoke.outputs.vnetName
    properties: {
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true
      remoteVirtualNetwork: {
        id: vnethub.id
      }
    }
  }
  dependsOn: [
    vnethub
    vnetspoke
  ]
}

module acr 'modules/storage/containerregistry.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'Deploy-Container-Registry-${acrName}'
  params: { 
    containerRegistryName: acrName
    containerRegistryPleName: acrPrivateEndpointName
    location: location
    subnetId: servicesSubnet.id
    tags:tags
  }
  dependsOn: [
    vnetspoke
  ]
}

module acrAccess 'modules/security/registry-access.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'Grant-ACR-Pull-Access-${acrName}'
  params: {
    containerRegistryName:acrName
    principalId: amlIdentity.outputs.principalId
  }
  dependsOn: [
    acr
  ]
}

module contributorAccess 'modules/security/role.bicep' = {
  scope: resourceGroup(rg.name)
  name:'Grant-Contributor-Access-${userAssignedIdentityName}'
  params: {
    principalId: amlIdentity.outputs.principalId
    roleDefinitionId: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  }
  dependsOn: [
    amlIdentity
  ]
}

module keyvault 'modules/security/keyvault.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'Deploy-KeyVault-${keyvaultName}'
  params: {
    location: location
    keyvaultName: keyvaultName
    keyvaultPleName: keyVaultPrivateEndpointName
    subnetId: servicesSubnet.id
  }
  dependsOn: [
    vnetspoke
  ]
}

module keyvaultAccess 'modules/security/keyvault-access.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'Grant-Key-Vault-Administrator-Access-${keyvaultName}'
  params: {
    keyVaultName:keyvaultName
    principalId: amlIdentity.outputs.principalId
    roleDefinitionID:	'00482a5a-887f-4fb3-b363-3b7fe8e74483' // Key Vault Administrator
    roleAssignmentName: guid(keyvaultName)
  }
  dependsOn: [
    keyvault
    amlIdentity
  ]
}

module storage 'modules/storage/storage.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'Deploy-Storage-Account-${storageAccountName}'
  params: {
    location: location
    storageName:storageAccountName
    storagePleBlobName: storagePleBlobName
    storagePleFileName: storagePleFileName
    subnetId: servicesSubnet.id
    tags:tags
  }
  dependsOn: [
    vnetspoke
  ]
}

module storageAccess 'modules/security/storage-access.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'Grant-Storage-Blob-Data-Contributor-${storageAccountName}'
  params: {
    principalId: amlIdentity.outputs.principalId
    roleDefinitionID:	'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
    roleAssignmentName: guid(storageAccountName)
    storageAccountName: storageAccountName
  }
  dependsOn: [
    storage
    amlIdentity
  ]
}

var blobPrivateDnsZoneName = 'privatelink.blob.${environment().suffixes.storage}'
var filePrivateDnsZoneName = 'privatelink.file.${environment().suffixes.storage}'
var acrPrivateDnsZoneName = 'privatelink${environment().suffixes.acrLoginServer}'
var keyVaultPrivateDnsZoneName = 'privatelink${environment().suffixes.keyvaultDns}'


module amlPrivateDnsZoneVnetLinkSpoke 'modules/networking/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'amlPrivateDnsZoneVnetLinkSpoke'
  params: { 
    name: 'spoke-${environmentName}'
    privateDnsZoneName:mlnetworking.outputs.amlPrivateDnsZoneName
    tags: tags
    virtualNetworkId:vnetspoke.outputs.vnetId
  }
  dependsOn: [
    mlnetworking
    vnetspoke
  ]
}

module amlPrivateDnsZoneVnetLinkHub 'modules/networking/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'amlPrivateDnsZoneVnetLinkHub'
  params: { 
    name: 'hub-${environmentName}'
    privateDnsZoneName:mlnetworking.outputs.amlPrivateDnsZoneName
    tags: tags
    virtualNetworkId:vnethub.id
  }
  dependsOn: [
    mlnetworking
    vnethub
  ]
}

module notebookPrivateDnsZoneVnetLinkSpoke 'modules/networking/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'notebookPrivateDnsZoneVnetLinkSpoke'
  params: { 
    name: 'spoke-${environmentName}'
    privateDnsZoneName:mlnetworking.outputs.notebookPrivateDnsZoneName
    tags: tags
    virtualNetworkId:vnetspoke.outputs.vnetId
  }
  dependsOn: [
    mlnetworking
    vnetspoke
  ]
}

module notebookPrivateDnsZoneVnetLinkHub 'modules/networking/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'notebookPrivateDnsZoneVnetLinkHub'
  params: { 
    name: 'hub-${environmentName}'
    privateDnsZoneName:mlnetworking.outputs.notebookPrivateDnsZoneName
    tags: tags
    virtualNetworkId:vnethub.id
  }
  dependsOn: [
    mlnetworking
    vnethub
  ]
}

module keyVaultPrivateDnsZoneVnetLinkSpoke 'modules/networking/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'keyVaultPrivateDnsZoneVnetLinkSpoke'
  params: { 
    name: 'spoke-${environmentName}'
    privateDnsZoneName:keyVaultPrivateDnsZoneName
    tags: tags
    virtualNetworkId:vnetspoke.outputs.vnetId
  }
  dependsOn: [
    keyvault
    vnetspoke
  ]
}

module keyVaultPrivateDnsZoneVnetLinkHub 'modules/networking/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'keyVaultPrivateDnsZoneVnetLinkHub'
  params: { 
    name: 'hub-${environmentName}'
    privateDnsZoneName:keyVaultPrivateDnsZoneName
    tags: tags
    virtualNetworkId:vnethub.id
  }
  dependsOn: [
    keyvault
    vnethub
  ]
}

module acrPrivateDnsZoneVnetLinkSpoke 'modules/networking/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'acrPrivateDnsZoneVnetLinkSpoke'
  params: { 
    name: 'spoke-${environmentName}'
    privateDnsZoneName:acrPrivateDnsZoneName
    tags: tags
    virtualNetworkId:vnetspoke.outputs.vnetId
  }
  dependsOn: [
    acr
    vnetspoke
  ]
}

module acrPrivateDnsZoneVnetLinkHub 'modules/networking/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'acrPrivateDnsZoneVnetLinkHub'
  params: { 
    name: 'hub-${environmentName}'
    privateDnsZoneName:acrPrivateDnsZoneName
    tags: tags
    virtualNetworkId:vnethub.id
  }
  dependsOn: [
    acr
    vnethub
  ]
}

module blobPrivateDnsZoneVnetLinkSpoke 'modules/networking/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'blobPrivateDnsZoneVnetLinkSpoke'
  params: { 
    name: 'spoke-${environmentName}'
    privateDnsZoneName:blobPrivateDnsZoneName
    tags: tags
    virtualNetworkId:vnetspoke.outputs.vnetId
  }
  dependsOn: [
    storage
    vnetspoke
  ]
}

module filePrivateDnsZoneVnetLinkSpoke 'modules/networking/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'filePrivateDnsZoneVnetLinkSpoke'
  params: { 
    name: 'spoke-${environmentName}'
    privateDnsZoneName:filePrivateDnsZoneName
    tags: tags
    virtualNetworkId:vnetspoke.outputs.vnetId
  }
  dependsOn: [
    storage
    vnetspoke
  ]
}

module blobPrivateDnsZoneVnetLinkHub 'modules/networking/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'blobPrivateDnsZoneVnetLinkHub'
  params: { 
    name: 'hub-${environmentName}'
    privateDnsZoneName:blobPrivateDnsZoneName
    tags: tags
    virtualNetworkId:vnethub.id
  }
  dependsOn: [
    storage
    vnethub
  ]
}

module filePrivateDnsZoneVnetLinkHub 'modules/networking/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'filePrivateDnsZoneVnetLinkHub'
  params: { 
    name: 'hub-${environmentName}'
    privateDnsZoneName:filePrivateDnsZoneName
    tags: tags
    virtualNetworkId:vnethub.id
  }
  dependsOn: [
    storage
    vnethub
  ]
}

module cognitiveservices 'modules/ai/cognitiveservices.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'Deploy-Open-AI-Services-${cognitiveservicesname}'
  params: {
    name: cognitiveservicesname
    location: cognitiveservicesLocation
    resourceGroupName:rg.name
    userAssignedIdentityName: userAssignedIdentityName
    deployments:openAiDeployments
  }
  dependsOn: [
    vnetspoke
    amlIdentity
  ]
}

module monitoring 'modules/monitor/monitoring.bicep' = {
  name: 'Deploy-monitoring-${environmentName}'
  scope: resourceGroup(rg.name)
  params: {
    location: location
    tags: tags
    logAnalyticsName: logAnalyticsName
    applicationInsightsName: applicationInsightsName
    applicationInsightsDashboardName: applicationInsightsDashboardName
  }
  dependsOn: [
    vnetspoke
  ]
}

resource servicesSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  scope: resourceGroup(rg.name)
  name: '${vnetSpokeName}/${spokePVSubnetname}'
}

module amlIdentity 'modules/security/userassigned.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'amlIdentity'
  params: {
    location: location
    identityName: userAssignedIdentityName
  }
  dependsOn: [
    rg
  ]
}

module azuremlWorkspace 'modules/aml/machinelearning.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'Deploy-AML-${machinellearningworkspacename}'
  params: {
    workspaceComputeName: workspaceComputeName
    storageAccount_name: storageAccountName
    userAssignedIdentityName: userAssignedIdentityName
    resourceGroupName:rg.name
    workspacename: machinellearningworkspacename
    workspaceFriendlyName: 'Auto-Created Secured Workspace.'
    workspaceDescription: 'Secured Workspace.'    
    location: location    
    tags: tags    
    storageAccount_externalid: storage.outputs.storageId
    keyVault_externalid: keyvault.outputs.keyvaultId
    applicationInsights_externalid: monitoring.outputs.applicationInsightsId
    openAI_externalid: cognitiveservices.outputs.id
    containerRegistry_externalid: acr.outputs.containerRegistryId
  }
  dependsOn: [
    keyvault
    acr
    monitoring
    storage
    cognitiveservices
    amlIdentity
  ]
}

module azuremlCompute 'modules/aml/machinelearningcompute.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'Deploy-AML-Compute-${machinellearningworkspacename}'
  params: {
    location: location
    resourceGroupName: rg.name 
    userAssignedIdentityName: userAssignedIdentityName
    vmSizeParam: amlComputeDefaultVmSize
    workspaceComputeName: workspaceComputeName
    workspacename: machinellearningworkspacename
  }
  dependsOn: [
    azuremlWorkspace
    notebookPrivateDnsZoneVnetLinkHub
    notebookPrivateDnsZoneVnetLinkSpoke
    amlPrivateDnsZoneVnetLinkHub
    amlPrivateDnsZoneVnetLinkSpoke
    mlnetworking
  ]
}
