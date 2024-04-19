@description('VM size for the default compute cluster')
param vmSizeParam string

param workspaceComputeName string

@description('Azure Machine Learning workspace name')
param workspacename string

@description('Azure region of the deployment')
param location string

param resourceGroupName string
param userAssignedIdentityName string

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
    scope: resourceGroup(resourceGroupName)
    name: userAssignedIdentityName
}

resource workspace 'Microsoft.MachineLearningServices/workspaces@2023-10-01' existing = {
  scope: resourceGroup(resourceGroupName)
  name: workspacename
}


resource workspaces_compute_cluster 'Microsoft.MachineLearningServices/workspaces/computes@2023-10-01' = {
  name: '${workspace.name}/${workspaceComputeName}-cluster'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}' : {}
    }
  }
  properties: {
    computeType: 'AmlCompute'
    computeLocation: location
    description: 'Machine Learning Cluster'
    disableLocalAuth: true
    properties: {
      vmPriority: 'Dedicated'
      vmSize: vmSizeParam
      enableNodePublicIp: false
      isolatedNetwork: true
      osType: 'Linux'
      remoteLoginPortPublicAccess: 'Disabled'
      scaleSettings: {
        minNodeCount: 0
        maxNodeCount: 5
        nodeIdleTimeBeforeScaleDown: 'PT120S'
      }
    }
  }
}

resource workspaces_compute 'Microsoft.MachineLearningServices/workspaces/computes@2023-10-01' = {
  name: '${workspace.name}/${workspaceComputeName}'  
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}' : {}
    }
  }
  properties: {
    computeLocation: location
    description: 'Personal Compute'
    disableLocalAuth: true
    computeType: 'ComputeInstance'
    properties: {
      applicationSharingPolicy: 'Personal'
      computeInstanceAuthorizationType: 'personal'
      enableNodePublicIp: false
      sshSettings: {
        sshPublicAccess: 'Disabled'
      }
      vmSize: vmSizeParam
    }
  }
}
