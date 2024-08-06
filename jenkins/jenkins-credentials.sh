#!/bin/bash

# Jenkins server details
JENKINS_URL="<Jenkins URL>"
USER="<Jenkins user ID>"
API_TOKEN="<Jenkins API token>"

PASSWORD=$(pwgen -N1 -s 128)
COSIGN_PASSWORD=$PASSWORD cosign generate-key-pair
COSIGN_SECRET_PASSWORD="$(base64 -w0 <<< $PASSWORD)"
COSIGN_SECRET_KEY="$(base64 -w0 < cosign.key)"
COSIGN_PUBLIC_KEY="$(base64 -w0 < cosign.pub)"


# Arrays of credential details
CREDENTIAL_IDS=("ROX_API_TOKEN" "ROX_CENTRAL_ENDPOINT" "GITOPS_AUTH_PASSWORD", "COSIGN_SECRET_PASSWORD", "COSIGN_SECRET_KEY", "COSIGN_PUBLIC_KEY")
SECRETS=("<ACS token>" "<ACS endpoint>" "<GitOps token>", $COSIGN_SECRET_PASSWORD, $COSIGN_SECRET_KEY, $COSIGN_PUBLIC_KEY)

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
