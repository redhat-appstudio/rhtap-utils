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
export GITHUB__APP__WEBHOOK__SECRET="<REPLACE_ME, a random string>"
export GITOPS__GIT_TOKEN="<REPLACE_ME>"
export QUAY__DOCKERCONFIGJSON="<REPLACE_ME>"
export QUAY__API_TOKEN="<REPLACE_ME>"
export ACS__CENTRAL_ENDPOINT="<REPLACE_ME>"
export ACS__API_TOKEN="<REPLACE_ME>"

install_rhtap() {
  # Path to your values.yaml.tpl file
  tpl_file="charts/values.yaml.tpl"

#   # Create the new integrations section
  cat <<EOF >> $tpl_file
integrations:
  github:
    id: "${GITHUB__APP__ID}"
    clientId: "${GITHUB__APP__CLIENT__ID}"
    clientSecret: "${GITHUB__APP__CLIENT__SECRET}"
    publicKey: |-
$(echo "${GITHUB__APP__PRIVATE_KEY}" | sed 's/^/      /')
    token: "${GITOPS__GIT_TOKEN}"
    webhookSecret: "${GITHUB__APP__WEBHOOK__SECRET}"
EOF

  # disable ACS installation
  # yq e '.rhtapCLI.features.redHatAdvancedClusterSecurity.enabled = false' -i config.yaml
  # disable Quay installation
  # yq e '.rhtapCLI.features.redHatQuay.enabled = false' -i config.yaml

  echo "make build"
  make build

  echo "install"
  ./bin/rhtap-cli integration --kube-config "$KUBECONFIG" quay --url="https://quay.io" --dockerconfigjson="${QUAY__DOCKERCONFIGJSON}" --token="${QUAY__API_TOKEN}"
  ./bin/rhtap-cli integration --kube-config "$KUBECONFIG" acs --endpoint="${ACS__CENTRAL_ENDPOINT}" --token="${ACS__API_TOKEN}"
  ./bin/rhtap-cli deploy --timeout 25m --config ./config.yaml --kube-config "$KUBECONFIG" --debug --log-level=debug

  homepage_url=https://$(kubectl -n rhtap get route backstage-developer-hub -o  'jsonpath={.spec.host}')
  callback_url=https://$(kubectl -n rhtap get route backstage-developer-hub -o  'jsonpath={.spec.host}')/api/auth/github/handler/frame
  webhook_url=https://$(kubectl -n openshift-pipelines get route pipelines-as-code-controller -o 'jsonpath={.spec.host}')

  echo "homepage_url=$homepage_url"
  echo "callback_url=$callback_url"
  echo "webhook_url=$webhook_url"
} 
# update_github_app()
unit_test(){
  echo "unit test"
  make test
}

jwt_token() {
  app_id=$1     # App ID as first argument
  pem=$(cat "$2") # file path of the private key as second argument

  now=$(date +%s)
  iat=$((now - 60))  # Issues 60 seconds in the past
  exp=$((now + 600)) # Expires 10 minutes in the future

  b64enc() { openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n'; }

  header_json='{
      "typ":"JWT",
      "alg":"RS256"
  }'
  # Header encode
  header=$(echo -n "${header_json}" | b64enc)

  payload_json='{
      "iat":'"${iat}"',
      "exp":'"${exp}"',
      "iss":'"${app_id}"'
  }'
  # Payload encode
  payload=$(echo -n "${payload_json}" | b64enc)

  # Signature
  header_payload="${header}"."${payload}"
  signature=$(
      openssl dgst -sha256 -sign <(echo -n "${pem}") \
          <(echo -n "${header_payload}") | b64enc
  )

  # Create JWT
  JWT_TOKEN="${header_payload}"."${signature}"
}

update_github_app() {
  echo "Update GitHub App"
  curl \
    -X PATCH \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    https://api.github.com/app/hook/config \
    -d "{\"content_type\":\"json\",\"insecure_ssl\":\"0\",\"secret\":\"$GITHUB__APP__WEBHOOK__SECRET\",\"url\":\"$webhook_url\"}" &>/dev/null
}

cleanup() {
  echo "Cleanup"
  git checkout -- charts/values.yaml.tpl
  git checkout -- config.yaml
}

cleanup
install_rhtap
update_github_app
# unit_test