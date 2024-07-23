#!/usr/bin/env bash

#quit if exit status of any cmd is a non-zero value
set -o errexit
set -o nounset
set -o pipefail


github_app_private_key_path="<REPLACE_ME>"

export GITHUB__APP__ID="<REPLACE_ME>"
export GITHUB__APP__CLIENT__ID="<REPLACE_ME>"
export GITHUB__APP__CLIENT__SECRET="<REPLACE_ME>"
export GITHUB__APP__PRIVATE_KEY=$(cat $github_app_private_key_path)
export GITHUB__APP__WEBHOOK__SECRET="<REPLACE_ME>"
export GITOPS__GIT_TOKEN="<REPLACE_ME>"
export GITLAB__TOKEN="<REPLACE_ME>"
export QUAY__DOCKERCONFIGJSON="<REPLACE_ME>"
export QUAY__API_TOKEN="<REPLACE_ME>"
export ACS__CENTRAL_ENDPOINT="<REPLACE_ME>"
export ACS__API_TOKEN="<REPLACE_ME>"

# Path to your values.yaml.tpl file
tpl_file="charts/values.yaml.tpl"

# Create the new integrations section
cat <<EOF >> $tpl_file
integrations:
  acs:
    endpoint: "${ACS__CENTRAL_ENDPOINT}"
    token: "${ACS__API_TOKEN}"
  github:
    id: "${GITHUB__APP__ID}"
    clientId: "${GITHUB__APP__CLIENT__ID}"
    clientSecret: "${GITHUB__APP__CLIENT__SECRET}"
    publicKey: |-
$(echo "${GITHUB__APP__PRIVATE_KEY}" | sed 's/^/      /')
    token: "${GITOPS__GIT_TOKEN}"
    webhookSecret: "${GITHUB__APP__WEBHOOK__SECRET}"
#  gitlab:
#    token: "${GITLAB__TOKEN}"
  quay:
    dockerconfigjson: ${QUAY__DOCKERCONFIGJSON}
    token: "${QUAY__API_TOKEN}"
EOF

# disable ACS installation
yq e '.rhtapCLI.features.redHatAdvancedClusterSecurity.enabled = false' -i config.yaml
# disable Quay installation
yq e '.rhtapCLI.features.redHatQuay.enabled = false' -i config.yaml

echo "make build"
make build

echo "install"
./bin/rhtap-cli deploy --config ./config.yaml --kube-config "$KUBECONFIG" --debug --log-level=debug

# make test