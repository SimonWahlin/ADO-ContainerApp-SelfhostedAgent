@description('Name of the Azure Container Registry')
param registryName string

@description('Name of the manual image build task, use a unique name to build a new image')
param manualTaskIdentifier string = 'first-run'

@description('Name of the User Assigned Managed Identity, maximum 128 characters.')
param managedIdentityName string = 'devops-agent-stateless-uami'

@description('The tags to associate with the Log Analytics Workspace.')
param tags object = {}

@description('The location of the Key Vault.')
param location string = resourceGroup().location

var roleDefinitionAcrPull = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
  tags: tags
}

resource registry 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: registryName
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    zoneRedundancy: 'Enabled'
  }
  tags: tags
}

resource managedIdentityRoleassignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(managedIdentityName, roleDefinitionAcrPull, registry.id)
  properties: {
    principalId: userAssignedIdentity.properties.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionAcrPull)
  }
}

resource imageBuildSchedule 'Microsoft.ContainerRegistry/registries/tasks@2019-06-01-preview' = {
  name: 'ado-agent-stateless-build'
  location: resourceGroup().location
  parent: registry
  properties: {
    platform: {
      os: 'Linux'
      architecture: 'amd64'
    }
    step: {
      dockerFilePath: 'dockerfile'
      contextPath: 'https://github.com/SimonWahlin/ADO-ContainerApp-SelfhostedAgent.git#main'
      type: 'Docker'
      imageNames: [
        'ado-agent-stateless:latest'
        'ado-agent-stateless:{{.Run.ID}}'
      ]
      noCache: true
    }
    trigger: {
      timerTriggers: [
        {
          name: 'weekly'
          schedule: '0 0 * * 0'
          status: 'Enabled'
        }
      ]
    }
  }
}

resource imageBuildManualTask 'Microsoft.ContainerRegistry/registries/taskRuns@2019-06-01-preview' = {
  name: manualTaskIdentifier
  parent: registry
  properties: {
    runRequest: {
      type: 'DockerBuildRequest'
      dockerFilePath: 'dockerfile'
      imageNames: [
        'ado-agent-stateless:latest'
        'ado-agent-stateless:{{.Run.ID}}'
      ]
      noCache: true
      platform: {
        os: 'Linux'
        architecture: 'amd64'
      }
      sourceLocation: 'https://github.com/SimonWahlin/ADO-ContainerApp-SelfhostedAgent.git#main'
    }
  }
}

output identityResourceId string = userAssignedIdentity.id

output identityName string = userAssignedIdentity.name

output identityClientId string = userAssignedIdentity.properties.clientId

output identityPrincipalId string = userAssignedIdentity.properties.principalId
