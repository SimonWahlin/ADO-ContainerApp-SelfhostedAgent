metadata name = 'Azure Container Registry'
metadata description = 'This module deploys a Container Registry and optionally private endpoints.'
metadata owner = 'PalmEmanuel'
metadata version = '1.0.0'

@description('Required. Name of the Container Registry')
param registryName string

@description('Optional. Public network access for the Container Registry')
param publicNetworkAccess ('Enabled'|'Disabled') = 'Enabled'

@description('Optional. Name and subnetId of the Private Endpoints that will be deployed for the Container Registry')
param privateEndpointConfiguration privateEndpointConfigurationType[] = []

@description('Optional. IP Ranges allowed to access the Container Registry')
param registryAllowedIpRanges array = []

@description('Optional. Default action for the network rule set, set to allow to allow all traffic by default')
param networkRuleDefaultAction string = 'Deny'

@description('Optional. Location of the Container Registry')
param location string = resourceGroup().location

@description('Optional. Tags of the Container Registry')
param tags object = {}

resource registry 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: registryName
  location: location
  sku: {
    name: 'Premium'
  }
  tags: tags
  properties: {
    publicNetworkAccess: publicNetworkAccess
    adminUserEnabled: false
    zoneRedundancy: 'Enabled'
    networkRuleBypassOptions: 'None'
    networkRuleSet: {
      defaultAction: networkRuleDefaultAction
      ipRules: [for ipRange in registryAllowedIpRanges: {
        value: ipRange
        action: 'Allow'
      }]
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-05-01' = [for pend in privateEndpointConfiguration: {
  name: pend.name
  location: location
  properties: {
    subnet: {
      id: resourceId(split(pend.subnetId,'/')[2],split(pend.subnetId,'/')[4],'Microsoft.Network/virtualNetworks/subnets',split(pend.subnetId,'/')[8],split(pend.subnetId,'/')[10])
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-${registryName}'
        properties: {
          privateLinkServiceId: registry.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
}]

output registryId string = registry.id

output name string = registry.name

type privateEndpointConfigurationType = {
  name: string
  subnetId: string
}
