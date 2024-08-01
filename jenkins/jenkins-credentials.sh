#!/bin/bash

# Jenkins server details
JENKINS_URL="<jenkins instance URL>"
echo $JENKINS_URL
USER="<jenkins user>"
API_TOKEN="<jenkins API token>"

# Arrays of credential details
CREDENTIAL_IDS=("ROX_API_TOKEN" "ROX_CENTRAL_ENDPOINT" "GITOPS_AUTH_PASSWORD")
SECRETS=("<acs token>" "<acs endpoint>" "<GitOps token>")

# Function to add a single credential
add_credential() {
    local id=$1
    local secret=$2

    local json=$(cat <<EOF
{
  "": "0",
  "credentials": {
    "scope": "GLOBAL",
    "id": "${id}",
    "secret": "${secret}",
    "description": "",
    "\$class": "org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl"
  }
}
EOF
)
    curl -X POST "$JENKINS_URL/credentials/store/system/domain/_/createCredentials" \
    --user "$USER:$API_TOKEN" \
    --data-urlencode "json=$json"
}

curl -X POST "$JENKINS_URL/credentials/store/system/domain/_/createCredentials" \
--user "$USER:$API_TOKEN" \
--data-urlencode 'json={
  "": "0",
  "credentials": {
    "scope": "GLOBAL",
    "id": "QUAY_IO_CREDS",
    "username": "<Quay username>",
    "password": "<Quay password>",
    "description": "",
    "$class": "com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl"
  }
}'


# Add multiple credentials
for i in "${!CREDENTIAL_IDS[@]}"; do
    add_credential "${CREDENTIAL_IDS[$i]}" "${SECRETS[$i]}"
done
