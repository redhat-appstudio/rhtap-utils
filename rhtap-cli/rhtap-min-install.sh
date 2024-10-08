#!/usr/bin/env bash

#quit if exit status of any cmd is a non-zero value
set -o errexit
set -o nounset
set -o pipefail

## Uncomment when running locally
#export KUBECONFIG="<REPLACE_ME>"

## The default catalog URL of the developer hub
export DEVELOPER_HUB__CATALOG__URL="<REPLACE_ME, for example: https://github.com/redhat-appstudio/tssc-sample-templates/blob/main/all.yaml>"

## Existing Github app, see function "githubapp_integration"
export GITHUB__APP__CLIENT__ID="<REPLACE_ME>"
export GITHUB__APP__CLIENT__SECRET="<REPLACE_ME>"
export GITHUB__APP__ID="<REPLACE_ME>"
export GITHUB__APP__PRIVATE_KEY="<REPLACE_ME, base64 encoded key, for example: $(cat rhtap-test.2024-03-26.private-key.pem | base64 -w 0) >"
export GITOPS__GIT_TOKEN="<REPLACE_ME>"
export GITHUB__APP__WEBHOOK__SECRET="<REPLACE_ME, a random string>"

## Exisitng Gitlab server, see function "gitlab_integration"
export GITLAB__TOKEN="<REPLACE_ME, create a Personal access tokens in page https://gitlab.com/-/user_settings/personal_access_tokens>"

## External Jenkins server, see function "jenkins_integration". Please refer to guide https://github.com/redhat-appstudio/rhtap-utils/blob/main/jenkins/README-JENKINS.md
export JENKINS__TOKEN="<REPLACE_ME>"                                  
export JENKINS__URL="<REPLACE_ME>"
export JENKINS__USERNAME="<REPLACE_ME>"

readonly tpl_file="installer/charts/values.yaml.tpl"
readonly config_file="installer/config.yaml"

ci_enabled() {
  echo "[INFO]Turn ci to true, this is required when you perform rhtap-e2e automation test against RHTAP"
  sed -i'' -e 's/ci: false/ci: true/g' $tpl_file
}

jenkins_integration() {
  echo "[INFO] Integrates an exising Jenkins server into RHTAP"
  ./bin/rhtap-cli integration --kube-config "$KUBECONFIG" jenkins --token="$JENKINS__TOKEN" --url="$JENKINS__URL" --username="$JENKINS__USERNAME"
}

gitlab_integration() {
  echo "[INFO] Configure an external Gitlab integration into RHTAP"
  ./bin/rhtap-cli integration --kube-config "$KUBECONFIG" gitlab --token "${GITLAB__TOKEN}"
}

githubapp_integration() {
  echo "[INFO] Config Github App integration in RHTAP"

  cat <<EOF >>"$tpl_file"
integrations:
  github:
    id: "${GITHUB__APP__ID}"
    clientId: "${GITHUB__APP__CLIENT__ID}"
    clientSecret: "${GITHUB__APP__CLIENT__SECRET}"
    publicKey: |-
$(echo "${GITHUB__APP__PRIVATE_KEY}" | base64 -d | sed 's/^/      /')
    token: "${GITOPS__GIT_TOKEN}"
    webhookSecret: "${GITHUB__APP__WEBHOOK__SECRET}"
EOF
}

update_dh_catalog_url() {
  echo "[INFO]Update dh catalog url"
  yq -i ".rhtapCLI.features.redHatDeveloperHub.properties.catalogURL = strenv(DEVELOPER_HUB__CATALOG__URL)" installer/config.yaml
}

quay_integration() {
  echo "[INFO] Configure quay.io integration into RHTAP"
  ./bin/rhtap-cli integration --kube-config "$KUBECONFIG" quay --url="https://quay.io" --dockerconfigjson="${QUAY__DOCKERCONFIGJSON}" --token="${QUAY__API_TOKEN}"
}

acs_integration() {
  echo "[INFO] Configure an external ACS integration into RHTAP"
  ./bin/rhtap-cli integration --kube-config "$KUBECONFIG" acs --endpoint="${ACS__CENTRAL_ENDPOINT}" --token="${ACS__API_TOKEN}"
}

install_rhtap() {
  echo "[INFO] Build RHTAP-CLI codes"
  make build

  echo "[INFO] Perfom RHTAP installation"
  update_dh_catalog_url # you can comment it if you don't need it
  githubapp_integration # you can comment it if you don't need it
  gitlab_integration  # you can comment it if you don't need it
  jenkins_integration # you can comment it if you don't need it
  quay_integration
  acs_integration
  ./bin/rhtap-cli deploy --timeout 35m --config $config_file --kube-config "$KUBECONFIG" --debug --log-level=debug

  homepage_url=https://$(kubectl -n rhtap get route backstage-developer-hub -o 'jsonpath={.spec.host}')
  callback_url=https://$(kubectl -n rhtap get route backstage-developer-hub -o 'jsonpath={.spec.host}')/api/auth/github/handler/frame
  webhook_url=https://$(kubectl -n openshift-pipelines get route pipelines-as-code-controller -o 'jsonpath={.spec.host}')

  echo "[INFO]homepage_url=$homepage_url"
  echo "[INFO]callback_url=$callback_url"
  echo "[INFO]webhook_url=$webhook_url"
}

unit_test(){
  echo "unit test"
  make test
}

jwt_token() {
  app_id=$1       # App ID as first argument
  pem=$2         # content of the private key as second argument

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
  echo "[INFO] Update Webhook url in GitHub App"
  github_private_key="$(echo -n ${GITHUB__APP__PRIVATE_KEY} | base64 -d)"
  jwt_token "$GITHUB__APP__ID" "$github_private_key"
  curl \
    -X PATCH \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    https://api.github.com/app/hook/config \
    -d "{\"content_type\":\"json\",\"insecure_ssl\":\"0\",\"secret\":\"$GITHUB__APP__WEBHOOK__SECRET\",\"url\":\"$webhook_url\"}" &>/dev/null

  echo "[INFO] Please manually update callback_url in GitHub App page to $callback_url"
}

cleanup() {
  echo "Cleanup"
  git checkout -- $tpl_file
  git checkout -- $config_file
}

run-rhtap-e2e() {
  export RED_HAT_DEVELOPER_HUB_URL GITHUB_TOKEN \
    GITHUB_ORGANIZATION QUAY_IMAGE_ORG APPLICATION_ROOT_NAMESPACE NODE_TLS_REJECT_UNAUTHORIZED GITLAB_TOKEN \
    GITLAB_ORGANIZATION QUAY_USERNAME QUAY_PASSWORD IMAGE_REGISTRY
  GITLAB_TOKEN="$GITLAB__TOKEN" 
  GITLAB_ORGANIZATION="<REPLACE_ME>"
  APPLICATION_ROOT_NAMESPACE="<REPLACE_ME>"
  QUAY_IMAGE_ORG="<REPLACE_ME>"
  GITHUB_ORGANIZATION="<REPLACE_ME>"
  GITHUB_TOKEN="$GITOPS__GIT_TOKEN"
  RED_HAT_DEVELOPER_HUB_URL="$homepage_url"
  IMAGE_REGISTRY="quay.io"
  NODE_TLS_REJECT_UNAUTHORIZED=0

  echo "[INFO] Run rhtap-e2e test"
  if [ -d "rhtap-e2e" ]; then
    echo "directory \"rhtap-e2e\" exists, delete it"
    rm -rf rhtap-e2e
  fi
  
  echo "[INFO] Clone rhtap-e2e repo"
  git clone https://github.com/redhat-appstudio/rhtap-e2e.git
  cd rhtap-e2e

  yarn && yarn test tests/gpts/github/quarkus.tekton.test.ts  # run a specific test
  # yarn && yarn test runTestsByPath tests/gpts/github/  # run all tests in the github folder
  # yarn && yarn test    # run all tests
}

cleanup
install_rhtap
update_github_app
# unit_test
run-rhtap-e2e
