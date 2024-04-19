@description('Azure Machine Learning workspace name')
param workspacename string

param workspaceFriendlyName string

param workspaceDescription string = 'Secured Workspace.'

@description('Azure region of the deployment')
param location string

@description('Tags to add to the resources')
param tags object


param storageAccount_externalid string
param storageAccount_name string
param keyVault_externalid string
param applicationInsights_externalid string
param openAI_externalid string
param containerRegistry_externalid string
param resourceGroupName string
param userAssignedIdentityName string
param workspaceComputeName string

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
    scope: resourceGroup(resourceGroupName)
    name: userAssignedIdentityName
}

resource workspace 'Microsoft.MachineLearningServices/workspaces@2023-10-01' = {
  name: workspacename
  location: location
  tags: tags
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  kind: 'Default'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}' : {}
    }
  }
  properties: {
    imageBuildCompute: workspaceComputeName
    primaryUserAssignedIdentity:userAssignedIdentity.id
    friendlyName: workspaceFriendlyName
    description: workspaceDescription
    storageAccount: storageAccount_externalid
    keyVault: keyVault_externalid
    applicationInsights: applicationInsights_externalid
    hbiWorkspace: false
    managedNetwork: {
      isolationMode: 'AllowOnlyApprovedOutbound'
      outboundRules: {
        'azure-examples-storage': {
          type: 'FQDN'
          destination: 'azuremlexamples.blob.core.windows.net'
          status: 'Active'
          category: 'UserDefined'
        }
        pypi: {
          type: 'FQDN'
          destination: 'pypi.org'
          status: 'Active'
          category: 'UserDefined'
        }
        python: {
          type: 'FQDN'
          destination: 'pypi.python.org'
          status: 'Active'
          category: 'UserDefined'
        }
        pythonhosted: {
          type: 'FQDN'
          destination: 'pythonhosted.org'
          status: 'Active'
          category: 'UserDefined'
        }
        pythonhostedfiles: {
          type: 'FQDN'
          destination: 'files.pythonhosted.org'
          status: 'Active'
          category: 'UserDefined'
        }
        mslearn: {
          type: 'FQDN'
          destination: 'learn.microsoft.com'
          status: 'Active'
          category: 'UserDefined'
        }
        openai: {
          type: 'PrivateEndpoint'
          destination: {
            serviceResourceId: openAI_externalid
            subresourceTarget: 'account'
            sparkEnabled: false
            sparkStatus: 'Inactive'
          }
          status: 'Active'
          category: 'UserDefined'
        }
      }
    }
    v1LegacyMode: false
    containerRegistry: containerRegistry_externalid
    publicNetworkAccess: 'Disabled'
  }
}

resource workspaces_workspaceblobstore 'Microsoft.MachineLearningServices/workspaces/datastores@2023-10-01' = {
  parent: workspace
  name: '${replace(workspacename, '-', '_')}_blob'
  properties: {
    accountName: storageAccount_name
    containerName: toLower(workspacename)
    datastoreType: 'AzureBlob'
    serviceDataAccessAuthIdentity:'WorkspaceUserAssignedIdentity'
    credentials: {
      credentialsType: 'None'
    }
  }
}

output workspaceId string = workspace.id
