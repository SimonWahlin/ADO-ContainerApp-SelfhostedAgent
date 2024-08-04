#!/bin/bash
set -e
resource="499b84ac-1321-427f-aa17-267ca6975798/.default"

if [ -z "${AZP_URL}" ]; then
  echo 1>&2 "error: missing AZP_URL environment variable"
  exit 1
fi

if [ -n "${AZP_CLIENTID}" ] && [ -n "${AZP_CLIENTSECRET}" ] && [ -n "${AZP_TENANTID}" ]; then          
  echo "Gettings token using CLIENT ID: ${AZP_CLIENTID} and sercret"
  AZP_TOKEN=$(curl -X POST -d "grant_type=client_credentials&client_id=${AZP_CLIENTID}&client_secret=${AZP_CLIENTSECRET}&resource=${resource}" https://login.microsoftonline.com/${AZP_TENANTID}/oauth2/token | jq -r '.access_token')
elif [ -n "${IDENTITY_ENDPOINT}" ] && [ -n "${IDENTITY_HEADER}" ]; then
  # Try to get token from managed identity
  if [ -n "${AZP_CLIENTID}" ]; then
    # We have a client id, let's get a token from userassigned managed identity
    echo "Using user-assigned managed identity with CLIENT ID: ${AZP_CLIENTID}"
    AZP_TOKEN=$(curl -X GET -H "X-IDENTITY-HEADER: ${IDENTITY_HEADER}" "${IDENTITY_ENDPOINT}?resource=${resource}&client_id=${AZP_CLIENTID}&api-version=2019-08-01" | jq -r '.access_token')
  else
    # We don't have a client id, let's get a token from systemassigned managed identity
    echo "Using system-assigned managed identity"
    AZP_TOKEN=$(curl -X GET -H "X-IDENTITY-HEADER: ${IDENTITY_HEADER}" "${IDENTITY_ENDPOINT}?resource=${resource}&api-version=2019-08-01" | jq -r '.access_token')
  fi
fi

if [ -z "${AZP_TOKEN_FILE}" ]; then
  if [ -z "${AZP_TOKEN}" ]; then
    echo 1>&2 "error: missing AZP_TOKEN environment variable"
    exit 1
  fi

  AZP_TOKEN_FILE="/azp/.token"
  echo -n "${AZP_TOKEN}" > "${AZP_TOKEN_FILE}"
fi

unset AZP_TOKEN

if [ -n "${AZP_WORK}" ]; then
  mkdir -p "${AZP_WORK}"
fi

cleanup() {
  trap "" EXIT
  # If $AZP_PLACEHOLDER is set, skip cleanup
  if [ -n "$AZP_PLACEHOLDER" ]; then
    echo 'Running in placeholder mode, skipping cleanup'
    return
  fi
  if [ -e ./config.sh ]; then
    print_header "Cleanup. Removing Azure Pipelines agent..."

    # If the agent has some running jobs, the configuration removal process will fail.
    # So, give it some time to finish the job.
    while true; do
      ./config.sh remove --unattended --auth "PAT" --token $(cat "${AZP_TOKEN_FILE}") && break

      echo "Retrying in 30 seconds..."
      sleep 30
    done
  fi
}

print_header() {
  lightcyan="\033[1;36m"
  nocolor="\033[0m"
  echo -e "\n${lightcyan}$1${nocolor}\n"
}

# Let the agent ignore the token env variables
export VSO_AGENT_IGNORE="AZP_TOKEN,AZP_TOKEN_FILE"

print_header "1. Determining matching Azure Pipelines agent..."

AZP_AGENT_PACKAGES=$(curl -LsS \
    -u user:$(cat "${AZP_TOKEN_FILE}") \
    -H "Accept:application/json;" \
    "${AZP_URL}/_apis/distributedtask/packages/agent?platform=${TARGETARCH}&top=1")

AZP_AGENT_PACKAGE_LATEST_URL=$(echo "${AZP_AGENT_PACKAGES}" | jq -r ".value[0].downloadUrl")

if [ -z "${AZP_AGENT_PACKAGE_LATEST_URL}" -o "${AZP_AGENT_PACKAGE_LATEST_URL}" == "null" ]; then
  echo 1>&2 "error: could not determine a matching Azure Pipelines agent"
  echo 1>&2 "check that account "${AZP_URL}" is correct and the token is valid for that account"
  exit 1
fi

print_header "2. Downloading and extracting Azure Pipelines agent..."

curl -LsS "${AZP_AGENT_PACKAGE_LATEST_URL}" | tar -xz & wait $!

source ./env.sh

trap "cleanup; exit 0" EXIT
trap "cleanup; exit 130" INT
trap "cleanup; exit 143" TERM

print_header "3. Configuring Azure Pipelines agent..."

args=(
  --unattended
  --agent "${AZP_AGENT_NAME:-$(hostname)}"
  --url "${AZP_URL}"
  --auth "PAT"
  --token $(cat "${AZP_TOKEN_FILE}")
  --pool "${AZP_POOL:-Default}"
  --work "${AZP_WORK:-_work}"
  --replace
  --acceptTeeEula
)

if [ -n "${AZP_PROXY_URL}" ]; then
  args+=(--proxyurl "${AZP_PROXY_URL}")
fi

if [ -n "${AZP_PROXY_USERNAME}" ]; then
  args+=(--proxyusername "${AZP_PROXY_USERNAME}")
fi

if [ -n "${AZP_PROXY_PASSWORD}" ]; then
  args+=(--proxypassword "${AZP_PROXY_PASSWORD}")
fi
echo "${args}"
./config.sh "${args[@]}" & wait $!

print_header "4. Running Azure Pipelines agent..."

chmod +x ./run.sh

# If $AZP_PLACEHOLDER is set, skipping running the agent
if [ -n "$AZP_PLACEHOLDER" ]; then
  echo 'Running in placeholder mode, skipping running the agent'
else
  # To be aware of TERM and INT signals call run.sh
  # Running it with the --once flag at the end will shut down the agent after the build is executed
  ./run.sh --once & wait $!
fi