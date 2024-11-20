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

# SBOM automatic upload creds
TRUSTIFICATION_BOMBASTIC_API_URL="$(kubectl get -n rhtap secrets/rhtap-trustification-integration --template={{.data.bombastic_api_url}} | base64 -d)"
TRUSTIFICATION_OIDC_ISSUER_URL="$(kubectl get -n rhtap secrets/rhtap-trustification-integration --template={{.data.oidc_issuer_url}} | base64 -d)"
TRUSTIFICATION_OIDC_CLIENT_ID="$(kubectl get -n rhtap secrets/rhtap-trustification-integration --template={{.data.oidc_client_id}} | base64 -d)"
TRUSTIFICATION_OIDC_CLIENT_SECRET="$(kubectl get -n rhtap secrets/rhtap-trustification-integration --template={{.data.oidc_client_secret}} | base64 -d)"
TRUSTIFICATION_SUPPORTED_CYCLONEDX_VERSION="$(kubectl get -n rhtap secrets/rhtap-trustification-integration --template={{.data.supported_cyclonedx_version}} | base64 -d)"


# Arrays of credential details
CREDENTIAL_IDS=("ROX_API_TOKEN" "ROX_CENTRAL_ENDPOINT" "GITOPS_AUTH_USERNAME" "GITOPS_AUTH_PASSWORD" "COSIGN_SECRET_PASSWORD" "COSIGN_SECRET_KEY" "COSIGN_PUBLIC_KEY" "TRUSTIFICATION_BOMBASTIC_API_URL" "TRUSTIFICATION_OIDC_ISSUER_URL" "TRUSTIFICATION_OIDC_CLIENT_ID" "TRUSTIFICATION_OIDC_CLIENT_SECRET" "TRUSTIFICATION_SUPPORTED_CYCLONEDX_VERSION")
SECRETS=($ACS_TOKEN $ACS_ENDPOINT $GITOPS_AUTH_USERNAME $GITOPS_GIT_TOKEN $COSIGN_SECRET_PASSWORD $COSIGN_SECRET_KEY $COSIGN_PUBLIC_KEY $TRUSTIFICATION_BOMBASTIC_API_URL $TRUSTIFICATION_OIDC_ISSUER_URL $TRUSTIFICATION_OIDC_CLIENT_ID $TRUSTIFICATION_OIDC_CLIENT_SECRET $TRUSTIFICATION_SUPPORTED_CYCLONEDX_VERSION)

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
    echo "Credential ${CREDENTIAL_IDS[$i]} is set" 
done

# Add usernames with passwords
add_username_with_password "QUAY_IO_CREDS" $QUAY_USERNAME $QUAY_PASSWORD
add_username_with_password "GITOPS_CREDENTIALS" $GITOPS_AUTH_USERNAME $GITOPS_GIT_TOKEN
