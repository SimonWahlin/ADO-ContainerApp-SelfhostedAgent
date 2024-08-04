# Azure DevOps self-hosted agent on Azure Container Apps

## Intro

What and why?
There are many reasons to run private hosted DevOps agents. Running an agent as a job in Azure Container Apps is low cost, low maintainence and very performant way to run a private hosted agent.
As a bonus, it should work behind a web proxy in an enterprise environment.

I am no fan of Personal Access Tokens, and for that reason, this solution relies on a user-assigned managed identity instead.

## Requirements

### Agent registration

The "agent pool administrator" role is required to register an agent to a pool. Assign the permission to the managed identity directly on the agent pool.

The following environment variables must be set for the image to work:
AZP_AGENT_NAME
AZP_URL
AZP_POOL

## Setup instructions for Sample

1. Deploy containerAppPrereqs.bicep which will:
   1. Deploy container registry
   2. Build and publish container image
   3. Create user-assigned managed identity
   4. Delegate access to container registry (Acr Pull role)
2. Invite user-assigned managed identity to DevOps Org
3. Create DevOps project and repository
4. Create Agent Pool
5. Grant user-assigned managed identity administrative access to Agent Pool
6. Deploy containerAppAgent.bicep which will:
   1. Deploy log analytics workspace
   2. Deploy Container App Environment
   3. Create placeholder agent manual job
   4. Create self-hosted agent as event driven job
7.  Run placeholder agent

### Proxy configuration

Set the folling environment variables to configure proxy:
AZP_PROXY_URL
AZP_PROXY_USERNAME
AZP_PROXY_PASSWORD

Create a file named .proxybypass in $(Agent.RootDirectory) for agent to bypass proxy for specific URLs.

### Authentication

This sample is using a user-assigned managed identity but the image 
To use `PAT` auth, add a PAT to the environment variable `AZP_TOKEN`.
To use a `service principal`, set the variables `AZP_CLIENTID`, `AZP_CLIENTSECRET` and `AZP_TENANTID`.
To use a `user-assigned managed identity`, only set the variable `AZP_CLIENTID`
If none of these variables are set, a `system assigned managed identity` will be used.

### Networking

This sample is deployed using only public endpoints but the container app environment can easily be network integrated.
The bicep module for the containerAppEnvironment has support for private networking.

## References

1. [Microsoft Learn: Tutorial: Deploy self-hosted CI/CD runners and agents with Azure Container Apps jobs](https://learn.microsoft.com/azure/container-apps/tutorial-ci-cd-runners-jobs?tabs=bash&pivots=container-apps-jobs-self-hosted-ci-cd-azure-pipelines)
2. [Microsoft Learn: Run a self-hosted agent in Docker](https://learn.microsoft.com/azure/devops/pipelines/agents/docker?view=azure-devops#linux)
3. [Microsoft Learn: Run a self-hosted agent behind a web proxy](https://learn.microsoft.com/azure/devops/pipelines/agents/proxy?view=azure-devops&tabs=unix)
4. [Microsoft Learn: Self-hosted agent authentication options](https://learn.microsoft.com/azure/devops/pipelines/agents/agent-authentication-options?view=azure-devops)
5. [Microsoft Learn: Register an agent using a service principal](https://learn.microsoft.com/azure/devops/pipelines/agents/service-principal-agent-registration?view=azure-devops)
6. [Microsoft Learn: Azure DevOps Agent Communication](https://learn.microsoft.com/azure/devops/pipelines/agents/agents?view=azure-devops&tabs=yaml%2Cbrowser#communication)
7. [Microsoft Learn: URLs to open in proxy](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/linux-agent?view=azure-devops#im-running-a-firewall-and-my-code-is-in-azure-repos-what-urls-does-the-agent-need-to-communicate-with)
8. Container Apps documentation
9. [Container Apps Jobs documentation](https://learn.microsoft.com/azure/container-apps/jobs?tabs=azure-resource-manager#jobs-restrictions)
10. [KEDA placeholder agent](https://keda.sh/blog/2021-05-27-azure-pipelines-scaler/#placeholder-agent)
11. [SELinux prevents ./svc.sh install executing](https://github.com/microsoft/azure-pipelines-agent/issues/2738)

