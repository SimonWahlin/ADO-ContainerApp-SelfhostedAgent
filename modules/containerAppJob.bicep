metadata name = 'Azure container app job'
metadata description = 'This template deploys an Azure container app job'
metadata author = 'SimonWahlin'
metadata version = '1.0.0'

@description('Required. Name of the conatiner app job')
param name string

@description('Required. Resource ID of container app environment')
param environmentId string

@description('Workload profile name to pin for container app execution')
param workloadProfileName string

@description('	List of container definitions for the Container Job')
param containers containerType[]

@description('List of specialized containers that run before app containers')
param initContainers initContainerType[] = []

@description('List of volume definitions')
param volumes volumeType[] = []

@description('Trigger configuration of an event driven job')
param eventTriggerConfig eventTriggerConfigType?

@description('Manual trigger configuration for a single execution job')
param manualTriggerConfig manualTriggerConfigType?

@description('Schedule trigger configuration for a recurring job')
param scheduleTriggerConfig scheduleTriggerConfigType?

@description('Maximum time in seconds for the container app job to run')
param replicaTimeout int = 3600

@description('Maximum number of retries before failing the container app job')
param replicaRetryLimit int = 0

@description('Collection of private container registry credentials')
param registryCredentials registryCredentialType[] = []

@description('	Collection of secrets used by a Container Apps Job')
param secrets secretsType[] = []

@description('Trigger type for the container app job')
param triggerType ('Event'|'Manual'|'Schedule') = 'Manual'

@description('Optional. The managed identity definition for this resource')
param managedIdentities managedIdentitiesType

@description('Tags of the resource')
param tags object = {}

@description('Location of all resources created')
param location string = resourceGroup().location

@description('''Converts the flat array to an object like { \'${id1}\': {}, \'${id2}\': {} }''')
var formattedUserAssignedIdentities = reduce(
  map((managedIdentities.?userAssignedResourceIds ?? []), (id) => { '${id}': {} }),
  {},
  (cur, next) => union(cur, next)
)

var identity = !empty(managedIdentities)
  ? {
      type: (managedIdentities.?systemAssigned ?? false)
        ? (!empty(managedIdentities.?userAssignedResourceIds ?? {}) ? 'SystemAssigned,UserAssigned' : 'SystemAssigned')
        : (!empty(managedIdentities.?userAssignedResourceIds ?? {}) ? 'UserAssigned' : 'None')
      userAssignedIdentities: !empty(formattedUserAssignedIdentities) ? formattedUserAssignedIdentities : null
    }
  : null

resource containerJob 'Microsoft.App/jobs@2024-02-02-Preview' = {
  name: name
  location: location
  identity: identity
  properties: {
    environmentId: environmentId
    workloadProfileName: workloadProfileName
    configuration: {
      eventTriggerConfig: eventTriggerConfig
      manualTriggerConfig: manualTriggerConfig
      registries: registryCredentials
      replicaRetryLimit: replicaRetryLimit
      replicaTimeout: replicaTimeout
      scheduleTriggerConfig: scheduleTriggerConfig
      secrets: secrets
      triggerType: triggerType
    }
    template: {
      containers: containers
      initContainers: initContainers
      volumes: volumes
    }
  }
  tags: tags
}

@description('The resource ID of the Container App')
output resourceId string = containerJob.id

@description('The name of the Container App')
output name string = containerJob.name

@description('The principal ID of the system assigned identity')
output systemAssignedMIPrincipalId string = containerJob.?identity.?principalId ?? ''

@export()
type managedIdentitiesType = {
  @description('Enables system assigned managed identity on the resource')
  systemAssigned: bool?

  @description('The resource ID(s) to assign to the resource')
  userAssignedResourceIds: string[]?
}?

@export()
type registryCredentialType = {
  @description('A Managed Identity to use to authenticate with Azure Container Registry. For user-assigned identities, use the full user-assigned identity Resource ID. For system-assigned identities, use \'system\'')
  identity: string?
  @description('The name of the Secret that contains the registry login password')
  passwordSecretRef: string?
  @description('Container Registry Server')
  server: string
  @description('Container Registry Username')
  username: string?
}

@export()
type eventTriggerConfigType = {
  parallelism: int?
  replicaCompletionCount: int?
  scale: {
    maxExecutions: int?
    minExecustions: int?
    pollingInterval: int?
    rules: scaleRuleType[]
  }
}

@export()
type scaleRuleType = {
  name: string
  @description('See https://keda.sh/docs/2.15/scalers/ for more information on scalers')
  type: string
  @description('Metadata to configure the scaler. Use the `any()` function to fit anything in here')
  metadata: object
  auth: [
    {
      @description('Name of the secret from which to pull the auth params')
      secretRef: string
      @description('Trigger Parameter that uses the secret')
      triggerParameter: string
    }
  ]?
  identity: string?
}

@export()
type scheduleTriggerConfigType = {
  cronExpression: string
  parallelism: int?
  replicaCompletionCount: int?
}

@export()
type manualTriggerConfigType = {
  @description('Number of parallel replicas of a job that can run at a given time')
  parallelism: int?
  @description('Minimum number of successful replica completions before overall job completion')
  replicaCompletionCount: int?
}

@export()
type secretsType = {
  @description('Resource ID of a managed identity to authenticate with Azure Key Vault, or System to use a system-assigned identity.')
  identity: string?

  @description('Name of the secret')
  name: string
  @description('Value of the secret')
  value: string
}

@export()
type containerType = {
  @description('Container start command arguments')
  args: string[]?
  @description('Container start command')
  command: string[]?
  @description('Container environment variables')
  env: environmentVarType[]?
  @description('Container image tag')
  image: string
  @description('Custom container name')
  name: string
  @description('List of probes for the container')
  probes: containerAppProbeType[]?
  @description(''''Container resource requirements, takes properties cpu and memory.  
  example:  
  ```bicep
  {
    cpu: json('0.25')
    memory: '0.5Gi'
  }
  ```
  ''')
  resources: object
  @description('Container volume mounts')
  volumeMounts: volumeMountType[]?
}

@export()
type initContainerType = {
  @description('Container start command arguments')
  args: string[]?
  @description('Container start command')
  command: string[]?
  @description('Container environment variables')
  env: environmentVarType[]?
  @description('Container image tag')
  image: string
  @description('Custom container name')
  name: string
  @description('''Container resource requirements, takes properties cpu and memory.  
  example:  
  ```bicep
  {
    cpu: json('0,25')
    memory: '0,5Gi'
  }
  ```
  ''')
  resources: object
  @description('Container volume mounts')
  volumeMounts: volumeMountType[]?
}

@export()
type environmentVarType = {
  @description('Environment variable name')
  name: string
  @description('Name of the Container App secret from which to pull the environment variable value')
  secretRef: string?
  @description('Non-secret environment variable value')
  value: string?
}

@export()
type containerAppProbeType = {
  @description('''
  Minimum consecutive failures for the probe to be considered failed after having succeeded.  
  Defaults to 3. Minimum value is 1. Maximum value is 10.  
  ''')
  failureThreshold: int?

  @description('''
  HTTPGet specifies the http request to perform.
  ''')
  httpGet: ContainerAppProbeHttpGetType

  @description('''
  Number of seconds after the container has started before liveness probes are initiated.  
  Minimum value is 1. Maximum value is 60.
  ''')
  initialDelaySeconds: int?

  @description('''
  How often (in seconds) to perform the probe.  
  Default to 10 seconds. Minimum value is 1. Maximum value is 240.
  ''')
  periodSeconds: int?

  @description('''
  Minimum consecutive successes for the probe to be considered successful after having failed.  
  Defaults to 1. Must be 1 for liveness and startup. Minimum value is 1. Maximum value is 10.
  ''')
  successThreshold: int?

  @description('''
  TCPSocket specifies an action involving a TCP port. TCP hooks not yet supported.
  ''')
  tcpSocket: ContainerAppProbeTcpSocketType

  @description('''
  Optional duration in seconds the pod needs to terminate gracefully upon probe failure.  
  The grace period is the duration in seconds after the processes running in the pod are sent a  
  termination signal and the time when the processes are forcibly halted with a kill signal.  
  Set this value longer than the expected cleanup time for your process. If this value is nil, the  
  pod\'s terminationGracePeriodSeconds will be used. Otherwise, this value overrides the value  
  provided by the pod spec. Value must be non-negative integer. The value zero indicates stop  
  immediately via the kill signal (no opportunity to shut down).  
  This is an alpha field and requires enabling ProbeTerminationGracePeriod feature gate.  
  Maximum value is 3600 seconds (1 hour)
  ''')
  terminationGracePeriodSeconds: int?

  @description('''
  Number of seconds after which the probe times out. Defaults to 1 second.  
  Minimum value is 1. Maximum value is 240.
  ''')
  timeoutSeconds: int?
  
  @description('''
  The type of probe.
  ''')
  type: ('Liveness'|'Readiness'|'Startup')?
}

@export()
type ContainerAppProbeHttpGetType = {
  @description('Host name to connect to, defaults to the pod IP. You probably want to set "Host" in httpHeaders instead')
  host: string?
  @description('Custom headers to set in the request. HTTP allows repeated headers')
  httpHeaders: ContainerAppProbeHttpGetHttpHeadersItem[]
  @description('Path to access on the HTTP server')
  path: string?
  @description('Name or number of the port to access on the container. Number must be in the range 1 to 65535. Name must be an IANA_SVC_NAME')
  port: int
  @description('Scheme to use for connecting to the host. Defaults to HTTP')
  scheme: ('HTTP'|'HTTPS')
}

@export()
type ContainerAppProbeTcpSocketType = {
  @description('Optional: Host name to connect to, defaults to the pod IP')
  host: string?
  @description('Number or name of the port to access on the container. Number must be in the range 1 to 65535. Name must be an IANA_SVC_NAME')
  port: int
}

@export()
type ContainerAppProbeHttpGetHttpHeadersItem = {
  @description('The header field name')
  name: string
  @description('The header field value')
  value: string
}

@export()
type volumeType = {
  @description('Mount options used while mounting the Azure file share or NFS Azure file share. Must be a comma-separated string')
  mountOptions: string?
  @description('Volume name')
  name: string
  @description('List of secrets to be added in volume. If no secrets are provided, all secrets in collection will be added to volume')
  secrets: volumeSecretType[]?
  @description('Name of storage resource. No need to provide for EmptyDir and Secret')
  storageName: string?
  @description('Storage type for the volume. If not provided, use EmptyDir')
  storageType: ('AzureFile'|'NfsAzureFile'|'EmptyDir'|'Secret')?
}

@export()
type volumeSecretType = {
  @description('Path to project secret to. If no path is provided, path defaults to name of secret listed in secretRef')
  path: string?
  @description('Name of the Container App secret from which to pull the secret value')
  secretRef: string
}

@export()
type volumeMountType = {
  @description('Path within the container at which the volume should be mounted. Must not contain \':\'')
  mountPath: string
  @description('Path within the volume from which the container\'s volume should be mounted. Defaults to \'\' (volume\'s root)')
  subPath: string?
  @description('This must match the Name of a Volume')
  volumeName: string
}
