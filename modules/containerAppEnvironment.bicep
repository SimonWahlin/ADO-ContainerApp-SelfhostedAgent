metadata name = 'Azure Container App Managed Environment'
metadata description = 'This module deploys a Container App Managed Environment.'
metadata owner = 'SimonWahlin'
metadata version = '1.0.0'

@description('Required. Name of the Container App Managed Environment.')
param name string

@description('Required. Existing Log Analytics Workspace resource ID. Note: This value is not required as per the resource type. However, not providing it currently causes an issue that is tracked [here](https://github.com/Azure/bicep/issues/9990).')
param logAnalyticsWorkspaceResourceId string

@description('Optional. Location for all Resources.')
param location string = resourceGroup().location

@description('Optional. Tags of the resource.')
param tags object?

@description('Optional. Logs destination, currently only log-analytics is supported in this template, see loganalyticsWorkspaceResourceId parameter.')
@allowed([
  'log-analytics'
  // 'azure-monitor'
  // ''
])
param logsDestination string = 'log-analytics'

@description('Optional. Application Insights connection string used by Dapr to export Service to Service communication telemetry.')
@secure()
param daprAIConnectionString string = ''

@description('Optional. Azure Monitor instrumentation key used by Dapr to export Service to Service communication telemetry.')
@secure()
param daprAIInstrumentationKey string = ''

@description('Optional. CIDR notation IP range assigned to the Docker bridge, network. It must not overlap with any other provided IP ranges and can only be used when the environment is deployed into a virtual network. If not provided, it will be set with a default value by the platform.')
param dockerBridgeCidr string = ''

@description('Conditional. Resource ID of a subnet for infrastructure components. This is used to deploy the environment into a virtual network. Must not overlap with any other provided IP ranges.')
param infrastructureSubnetId string = ''

@description('Optional. IP range in CIDR notation that can be reserved for environment infrastructure IP addresses. It must not overlap with any other provided IP ranges and can only be used when the environment is deployed into a virtual network. If not provided, it will be set with a default value by the platform.')
param platformReservedCidr string = ''

@description('Optional. An IP address from the IP range defined by "platformReservedCidr" that will be reserved for the internal DNS server. It must not be the first address in the range and can only be used when the environment is deployed into a virtual network. If not provided, it will be set with a default value by the platform.')
param platformReservedDnsIP string = ''

@description('Optional. Whether or not this Managed Environment is zone-redundant.')
param zoneRedundant bool = false

@description('Optional. Password of the certificate used by the custom domain.')
@secure()
param certificatePassword string = ''

@description('Optional. Certificate to use for the custom domain. PFX or PEM.')
@secure()
param certificateValue string = ''

@description('Optional. DNS suffix for the environment domain.')
param dnsSuffix string = ''

@description('Optional. Workload profiles configured for the Managed Environment.')
param workloadProfiles workloadProfileType[] = []

@description('Optional. Name of the infrastructure resource group. If not provided, it will be set with a default value.')
param infrastructureResourceGroupName string = take('ME_${name}', 63)

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: last(split(logAnalyticsWorkspaceResourceId, '/'))!
  scope: resourceGroup(split(logAnalyticsWorkspaceResourceId, '/')[2], split(logAnalyticsWorkspaceResourceId, '/')[4])
}

resource managedEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: logsDestination
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    daprAIConnectionString: daprAIConnectionString
    daprAIInstrumentationKey: daprAIInstrumentationKey
    customDomainConfiguration: {
      certificatePassword: certificatePassword
      certificateValue: !empty(certificateValue) ? certificateValue : null
      dnsSuffix: dnsSuffix
    }
    vnetConfiguration: {
      internal: infrastructureSubnetId != ''
      infrastructureSubnetId: !empty(infrastructureSubnetId) ? infrastructureSubnetId : null
      dockerBridgeCidr: !empty(infrastructureSubnetId) ? dockerBridgeCidr : null
      platformReservedCidr: empty(workloadProfiles) && !empty(infrastructureSubnetId) ? platformReservedCidr : null
      platformReservedDnsIP: empty(workloadProfiles) && !empty(infrastructureSubnetId) ? platformReservedDnsIP : null
    }
    workloadProfiles: workloadProfiles
    zoneRedundant: zoneRedundant
    infrastructureResourceGroup: infrastructureResourceGroupName
  }
}

@description('The name of the Managed Environment')
output name string = managedEnvironment.name

@description('The resource ID of the Managed Environment')
output resourceId string = managedEnvironment.id

@description('The Default domain of the Managed Environment')
output defaultDomain string = managedEnvironment.properties.defaultDomain

@description('Verification ID used to validate custom DNS domains for any app deployed in the ConatainerApp Environment')
output customDomainVerificationId string = managedEnvironment.properties.customDomainConfiguration.customDomainVerificationId

@description('Static IP of the Managed Environment')
output staticIp string = managedEnvironment.properties.staticIp

@export()
type workloadProfileType = {
  maximumCount: int?
  minimumCount: int?
  name: string
  workloadProfileType: ('Consumption' | 'D4' | 'D8' | 'D16' | 'D32' | 'E4' | 'E8' | 'E16' | 'E32' | 'NC24-A100' | 'NC48-A100' | 'NC96-A100')
}
