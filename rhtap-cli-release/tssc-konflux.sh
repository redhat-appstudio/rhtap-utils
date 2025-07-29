#!/usr/bin/env bash

# Script to create MR's to create new application version in konflux and release in konflux
# Script updates the files and creates MR's. It is left to
#   the user to get it MR's approved, merged and verify action completes
#   successfully in konflux.
# NOTE: rhtap-cli-stream.yaml is expected to be in order by version. Oldest version first entry,
#       new version last entry in file.

set -o errexit
set -o nounset
set -o pipefail

# Defaults
APP="rhtap-cli"
VERSION=""
ALT_VERSION=""
KEEP_VERSIONS="3"
REPOSITORY="${REPOSITORY:-konflux-release-data}"
GITLAB_ORG="${GITLAB_ORG:-releng}"
POSITIONAL_ARGS=()
KONFLUX_URL="https://konflux-ui.apps.stone-prd-rh01.pg1f.p1.openshiftapps.com"
KONFLUX_NAMESPACE="rhtap-shared-team-tenant"

# Files
STREAM_FILE="tenants-config/cluster/stone-prd-rh01/tenants/rhtap-shared-team-tenant/rhtap-cli-stream.yaml"
RP_FILE_DIR="tenants-config/cluster/stone-prd-rh01/tenants/rhtap-shared-team-tenant"
RPA_FILE_DIR="config/stone-prd-rh01.pg1f.p1/product/ReleasePlanAdmission/rhtap-shared-team"

# Messages
NEXT_STEPS="\nMerge Request Creation - SUCCESSFUL, See above for MR's URL\n
\nNEXT STEPS:\n
	1. Verify/Get MR Approved\n
        2. Merge MR and Verify Successful\n
"
REL_STEP="3. Konflux($KONFLUX_URL) Namespace($KONFLUX_NAMESPACE) - Verify Rlease pipeline started and once completed creation of Release is Successful\n"
APP_STEP="3. Konflux($KONFLUX_URL) Namespace($KONFLUX_NAMESPACE) - Verify Application Successfully added in Konflux.\n"
RELEASE_DOC="For detailed information on 'Release Steps' See: https://docs.google.com/document/d/1fxd-sq3IxLHWWqJM7Evhh9QeSXpqPMfRHHDBzAmT8-k/edit?tab=t.0#heading=h.9aaha887zz8f"

usage() {
    echo "
Usage:
    ${0##*/} [options] <action=app|release> <version>
       <action> =  Action app ( create application) or release (release application).
       <version> = Application version to create or release on konflux.

Optional arguments:
    --dry-run
        Do not push updates and create MR to merge into upstream main.
    -d, --debug
        Activate tracing/debug mode.
    -h, --help
        Display this message.
    -k, --keep
        Number of Versions to keep. Default is 3.
    -w, --wip
        Set work in progress, MR will be set as Draft
Example:
    ${0##*/} release 1.7
" >&2
}


parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        --dry-run)
            DRY_RUN=1
            ;;
        -d | --debug)
            set -x
            DEBUG="--debug"
            export DEBUG
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        -k | --keep)
            if [[ -n "$2" && "$2" != -* ]]; then
                KEEP_VERSIONS="$2"
                shift
            else
                echo "Error: Option $1 requires an argument."
                echo ""
                usage
                exit 1
            fi
            ;;
        -w | --wip)
            WIP=1
            ;;
        --) # End of options
            break
            ;;
        -*) # Unknown option
            echo "Error: Unknown option $1"
            usage
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            if [[ ${#POSITIONAL_ARGS[@]} -gt 2 ]]; then
                echo "[ERROR] Unknown argument: $1"
                usage
                exit 1
            elif [[ ${#POSITIONAL_ARGS[@]} -eq 1 ]]; then
                ACTION="$1"
                if [[ ${ACTION} != "app" && ${ACTION} != "release" ]]; then
                    echo "[ERROR] Action must be either 'app' or 'release'. Action: $ACTION"
                    usage
                    exit 1
                fi
            else
                VERSION="$1"
            fi
            ;;
        esac
        shift
    done

    if [[ "${#POSITIONAL_ARGS[@]}" -ne 2 ]]; then
        echo "[ERROR] Positional arguments 'action' and 'version' are required" 
        usage
        exit 1
    fi
}


init() {
    TMP_DIR=$(mktemp -d)
    PROJECT_DIR="$TMP_DIR/$REPOSITORY"
    trap cleanup EXIT

    git clone git@gitlab.cee.redhat.com:$GITLAB_ORG/$REPOSITORY.git --branch main --single-branch "$PROJECT_DIR"
    cd "$PROJECT_DIR"
}


cleanup() {
    if [ -z "${DRY_RUN:-}" ]; then
        rm -rf "$TMP_DIR"
    else
        echo -e "\nYou can browse the repository: $PROJECT_DIR"
    fi
}


create_branch() {
    git checkout -b "${APP}-${ACTION}-${VERSION}-${PKG}"
}


update_stream() {
    echo "---
apiVersion: projctl.konflux.dev/v1beta1
kind: ProjectDevelopmentStream
metadata:
  name: rhtap-cli-release-${ALT_VERSION}
spec:
  project: rhtap-cli
  template:
    name: rhtap-cli
    values:
      - name: version
        value: \"$VERSION\"
      - name: branchName
        value: \"release-$VERSION\"
" >> $STREAM_FILE

    NEW_NUM_VERSIONS=$((NUM_VERSIONS + 1))
}

delete_old_vers() {

    while  [[ $NEW_NUM_VERSIONS -gt $KEEP_VERSIONS ]] 
    do
        WORKING_VERSION=`yq eval-all 'select(documentIndex == 0) | .spec.template.values[] | select(.name == "version") | .value' $STREAM_FILE`
        WORKING_ALT_VERSION=$(echo "$WORKING_VERSION" | sed -r 's/\./-/g')

        # Delete old stream
        yq -i 'del(select(documentIndex == 0))' $STREAM_FILE 

        # Delete old corresponding RP
        rm $RP_FILE_DIR/rhtap-cli-rp-$WORKING_ALT_VERSION.yaml 

        # Delete old corresponding RPA
        rm $RPA_FILE_DIR/rhtap-cli-prod-$WORKING_ALT_VERSION.yaml

        NEW_NUM_VERSIONS=`yq eval-all '[.] | length' $STREAM_FILE`
    done
}

update_rp() {
    cp --update=none-fail $RP_FILE_DIR/rhtap-cli-rp-$CURRENT_ALT_VERSION.yaml $RP_FILE_DIR/rhtap-cli-rp-$ALT_VERSION.yaml
    SRCH_VERSION=$(echo "$CURRENT_VERSION" | sed -r 's/\./\\\./g')
    RPL_VERSION=$(echo "$VERSION" | sed -r 's/\./\\\./g')
    sed -i "s/$SRCH_VERSION/$RPL_VERSION/g" $RP_FILE_DIR/rhtap-cli-rp-$ALT_VERSION.yaml
    sed -i "s/$CURRENT_ALT_VERSION/$ALT_VERSION/g" $RP_FILE_DIR/rhtap-cli-rp-$ALT_VERSION.yaml
}


run_build_manifests() {
    # Complete modifications by running build-manifest.sh
    echo -e "Running build-manifests.sh"
    ./tenants-config/build-manifests.sh > /dev/null

    if [ $? -ne 0 ]; then
        echo "Error: Running of build-manifests failed"
        exit 1
    fi

    echo -e "Running of build-manifests.sh - SUCCESSFUL\n"

    # Pause for 10
    sleep 10
}


update_rpa() {
    cp --update=none-fail $RPA_FILE_DIR/rhtap-cli-prod-$PREV_ALT_VERSION.yaml $RPA_FILE_DIR/rhtap-cli-prod-$ALT_VERSION.yaml
    SRCH_VERSION=$(echo "$PREV_VERSION" | sed -r 's/\./\\\./g')
    RPL_VERSION=$(echo "$VERSION" | sed -r 's/\./\\\./g')
    sed -i "s/$SRCH_VERSION/$RPL_VERSION/g" $RPA_FILE_DIR/rhtap-cli-prod-$ALT_VERSION.yaml
    sed -i "s/$PREV_ALT_VERSION/$ALT_VERSION/g" $RPA_FILE_DIR/rhtap-cli-prod-$ALT_VERSION.yaml
}


commit_code() {
    git add --all .
    git commit -m "$MESSAGE"
}


release() {
    MESSAGE="release rhtap-cli $VERSION.0 (Automated)"
    PKG="rpa"

    NUM_VERSIONS=`yq eval-all '[.] | length' $STREAM_FILE`

    CURRENT_IDX=$((NUM_VERSIONS-1))
    VER_QUERY="yq eval-all 'select(documentIndex == $CURRENT_IDX) | .spec.template.values[] | select(.name == \"version\") | .value' $STREAM_FILE"
    CURRENT_VERSION=`eval "$VER_QUERY"`
    CURRENT_ALT_VERSION=$(echo "$CURRENT_VERSION" | sed -r 's/\./-/g')

    if [[ "$CURRENT_VERSION" != "$VERSION" ]]; then
        echo "[ERROR] Unable to release. App version $VERSION does look to be the latest."
        exit 1
    fi

    PREV_IDX="0"
    VER_QUERY="yq eval-all 'select(documentIndex == $PREV_IDX) | .spec.template.values[] | select(.name == \"version\") | .value' $STREAM_FILE"
    PREV_VERSION=`eval "$VER_QUERY"`
    PREV_ALT_VERSION=$(echo "$PREV_VERSION" | sed -r 's/\./-/g')

    create_branch

    echo -e "\nUpdating files"
    update_rpa
    echo -e "Updating files - SUCCESSFUL\n"

    commit_code
}


app() {
    MESSAGE="Update rhtap-cli-stream for setup of release $VERSION (Automated)"
    PKG="stream"

    NUM_VERSIONS=`yq eval-all '[.] | length' $STREAM_FILE`

    CURRENT_IDX=$((NUM_VERSIONS-1))
    VER_QUERY="yq eval-all 'select(documentIndex == $CURRENT_IDX) | .spec.template.values[] | select(.name == \"version\") | .value' $STREAM_FILE"
    CURRENT_VERSION=`eval "$VER_QUERY"`
    CURRENT_ALT_VERSION=$(echo "$CURRENT_VERSION" | sed -r 's/\./-/g')

    create_branch

    echo -e "\nUpdating files"
    update_stream
    update_rp
    delete_old_vers
    echo -e "Updating files - SUCCESSFUL\n"

    run_build_manifests

    commit_code
}

push_changes() {
    echo -e "\nPushing changes and creating MR\n"

    if [ -z "${WIP:-}" ]; then
        ADD_OPT=""
    else
        ADD_OPT="-o merge_request.draft"
    fi

    CREATE_MR_CMD="git push origin ${APP}-${ACTION}-${VERSION}-${PKG} -o merge_request.create $ADD_OPT -o merge_request.target=main -o merge_request.description=\"$DESCRIPTION\" -o merge_request.remove_source_branch -o merge_request.squash=true -o merge_request.merge_when_pipeline_succeeds"

    eval "$CREATE_MR_CMD"

    if [ "${ACTION}" == "release" ]; then
        NEXT_STEPS="$NEXT_STEPS$REL_STEP"
    else
        NEXT_STEPS="$NEXT_STEPS$APP_STEP"
    fi

    echo -e $NEXT_STEPS
    echo -e "$RELEASE_DOC"
}

action() {
    init

    # Set alternate version #-#
    ALT_VERSION=$(echo "$VERSION" | sed -r 's/\./-/g')

    if [ "${ACTION}" == "release" ]; then
        release
        TITLE=""
        DESCRIPTION="<h3>What:</h3>RPA is added for the rhtap-cli $VERSION application and component<br /><h3>Why:</h3>This PR is to release rhtap-cli $VERSION<br />"
    else
        app
        TITLE=""
        DESCRIPTION="<h3>What:</h3>This PR is in prep to onboard rhtap-cli release-$VERSION branch as application rhtap-cli-$ALT_VERSION<br /><h3>Why:</h3>We are preparing for rhtap-cli $VERSION release through rhtap-cli release-$VERSION branch<br />"
    fi

    if [ -z "${DRY_RUN:-}" ]; then
        push_changes
    fi
}

main() {
    parse_args "$@"
    action
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
    main "$@"
fi
