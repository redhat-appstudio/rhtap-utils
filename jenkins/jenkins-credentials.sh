#!/bin/bash

# Jenkins server details
JENKINS__URL="<Jenkins URL>"
JENKINS__USERNAME="<Jenkins user ID>"
JENKINS__TOKEN="<Jenkins API token>"

PASSWORD=$(pwgen -N1 -s 128)
COSIGN_PASSWORD=$PASSWORD cosign generate-key-pair
COSIGN_SECRET_PASSWORD="$(base64 -w0 <<< $PASSWORD)"
COSIGN_SECRET_KEY="$(base64 -w0 < cosign.key)"
COSIGN_PUBLIC_KEY="$(base64 -w0 < cosign.pub)"
GITOPS_AUTH_USERNAME="<GitOps username>"
GITOPS_GIT_TOKEN="<GitOps token>"
QUAY_USERNAME="<Quay username>"
QUAY_PASSWORD="<Quay password>"
ACS_TOKEN="<ACS token>"
ACS_ENDPOINT="<ACS endpoint>"


# Arrays of credential details
CREDENTIAL_IDS=("ROX_API_TOKEN" "ROX_CENTRAL_ENDPOINT" "GITOPS_AUTH_USERNAME" "GITOPS_AUTH_PASSWORD" "COSIGN_SECRET_PASSWORD" "COSIGN_SECRET_KEY" "COSIGN_PUBLIC_KEY")
SECRETS=($ACS_TOKEN $ACS_ENDPOINT $GITOPS_AUTH_USERNAME $GITOPS_GIT_TOKEN $COSIGN_SECRET_PASSWORD $COSIGN_SECRET_KEY $COSIGN_PUBLIC_KEY)

# Function to add a single credential
add_secret() {
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

    create_credentials "$json"    
}

add_username_with_password() {
    local id=$1
    local username=$2
    local password=$3

    local json=$(cat <<EOF
{
  "": "0",
  "credentials": {
    "scope": "GLOBAL",
    "id": "${id}",
    "username": "${username}",
    "password": "${password}",
    "description": "",
    "\$class": "com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl"
  }
}
EOF
)

    create_credentials "$json"
}

create_credentials() {
    local json=$1

    curl -X POST "$JENKINS__URL/credentials/store/system/domain/_/createCredentials" \
    --user "$JENKINS__USERNAME:$JENKINS__TOKEN" \
    --data-urlencode "json=$json"
}


# Add multiple credentials
for i in "${!CREDENTIAL_IDS[@]}"; do
    add_secret "${CREDENTIAL_IDS[$i]}" "${SECRETS[$i]}"
done

# Add usernames with passwords
add_username_with_password "QUAY_IO_CREDS" $QUAY_USERNAME $QUAY_PASSWORD
add_username_with_password "GITOPS_CREDENTIALS" $GITOPS_AUTH_USERNAME $GITOPS_GIT_TOKEN
