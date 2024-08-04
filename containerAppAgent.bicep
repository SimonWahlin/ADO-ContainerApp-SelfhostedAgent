metadata name = 'Azure container job running as a stateless Azure DevOps self-hosted agent'
metadata description = '''
This template deploys an Azure container environment with a Container App Job running as a stateless Azure DevOps self-hosted agent.
'''
metadata author = 'SimonWahlin'
metadata version = '1.0.0'

// import * as containerJobTypes from 'modules/containerAppJob.bicep'

@description('The name of the container app')
param containerJobName string = 'devops-agent-stateless2'

@description('The name of the container registry to create')
param devopsregistryName string = 'simonwadoagent.azurecr.io'

@description('User assigned identity with access to devops pool')
param userAssignedIdentityId string

@description('If using user assigned managed identity, set the ClientID here for the agent to use correct identity')
param userAssignedIdentityClientId string = ''

param poolName string = 'aca-stateless'
param poolId string = '13'
param devopsOrgUrl string = 'https://dev.azure.com/SimonWahlin'
param imageTag string = 'ado-agent-stateless:latest'

@description('Resource ID of the Log Analytics Workspace to use for logging. If not provided, a new Log Analytics Workspace will be created.')
param logAnalyticsWorkspaceResourceId string = ''

resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = if (logAnalyticsWorkspaceResourceId == '') {
  name: '${containerJobName}-logs'
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

module environment 'modules/containerAppEnvironment.bicep' = {
  name: '${containerJobName}-environment'
  params: {
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId == '' ? logs.id : logAnalyticsWorkspaceResourceId
    name: '${containerJobName}-env'
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

var envClientId = userAssignedIdentityClientId == '' ? [] :[
  {
    name: 'AZP_CLIENTID'
    value: userAssignedIdentityClientId
  }
]

var envStandard = [
  {
    name: 'AZP_URL'
    value: devopsOrgUrl
  }
  {
    name: 'AZP_POOL'
    value: poolName
  }
]

module containerJobPlaceholder 'modules/containerAppJob.bicep' = {
  name: '${containerJobName}-placehold'
  params: {
    name: '${containerJobName}-placehold'
    containers: [
      {
        name: 'ado-agent-stateless'
        image: '${devopsregistryName}/${imageTag}'
        resources: {
          cpu: json('2')
          memory: '4Gi'
        }
        env: union(envClientId, envStandard, [
          {
            name: 'AZP_PLACEHOLDER'
            value: 'true'
          }
          {
            name: 'AZP_AGENT_NAME'
            value: '${poolName}-placeholder-dontdelete'
          }
        ])
      }
    ]
    managedIdentities: {
      userAssignedResourceIds: [
        userAssignedIdentityId
      ]
    }
    environmentId: environment.outputs.resourceId
    workloadProfileName: 'Consumption'
    triggerType: 'Manual'
    manualTriggerConfig: {
      parallelism: 1
      replicaCompletionCount: 1
    }
    registryCredentials: [
      {
        server: devopsregistryName
        identity: userAssignedIdentityId
      }
    ]
  }
}

module containerJobAgemt 'modules/containerAppJob.bicep' = {
  name: '${containerJobName}-job2'
  params: {
    name: containerJobName
    containers: [
      {
        name: 'ado-agent-stateless'
        image: '${devopsregistryName}/${imageTag}'
        resources: {
          cpu: json('2')
          memory: '4Gi'
        }
        env: union(envClientId, envStandard, [
          {
            name: 'AZP_AGENT_NAME'
            value: poolName
          }
        ])
      }
    ]
    managedIdentities: {
      userAssignedResourceIds: [
        userAssignedIdentityId
      ]
    }
    environmentId: environment.outputs.resourceId
    workloadProfileName: 'Consumption'
    triggerType: 'Event'
    eventTriggerConfig: {
      scale: {
        rules: [
          {
            name: 'azure-pipelines'
            type: 'azure-pipelines'
            metadata: {
              poolName: poolName
            }
            auth: [
              {
                secretRef: 'azure-devops-organization-url'
                triggerParameter: 'organizationURL'
              }
            ]
            identity: userAssignedIdentityId
          }
        ]
      }
    }
    secrets: [
      {
        name: 'azure-devops-organization-url'
        value: devopsOrgUrl
      }
    ]
    registryCredentials: [
      {
        server: devopsregistryName
        identity: userAssignedIdentityId
      }
    ]
  }
}
