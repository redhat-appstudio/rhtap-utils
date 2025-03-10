#!/bin/bash 

# Set dry_run to true to not execute commands. It will display curl cmds to
#     create a branch, commits, mrs 
dry_run="${dry_run:-false}"
REPOSITORY="${REPOSITORY:-konflux-release-data}"
GITLAB_ORG="${GITLAB_ORG:-releng}"
VALID_STEPS=("all" "stream" "rpa")
STEPS=("all")

# Testing Variables
TEST="false"
TEST_VERSION="1.4"
TEST_MOD_VERSION="1-4"
TEST_NAMESPACE="rhtap-releng-tenant"
TEST_PIPELINE_RUN=""

STREAM_LIST=("tenants-config/cluster/stone-prd-rh01/tenants/rhtap-shared-team-tenant/rhtap-cli-stream.yaml")
RPA_LIST=("config/stone-prd-rh01.pg1f.p1/product/ReleasePlanAdmission/rhtap-shared-team/rhtap-cli-prod.yaml")

cleanup() {
    if [ -v "PREFIX" ] && [ -n "$PREFIX" ]; then
        rm -rf /tmp/$PREFIX-stream
        rm -rf /tmp/$PREFIX-rpa
    fi
}

help_text() {
    echo " "
    echo "$0 - Automates the release process of a new rhtap-cli"
    echo "     version through konflux by updating rhtap-cli-stream and"
    echo "     the RPA"
    echo " "
    echo "$0 [options]"
    echo " "
    echo "Note: Environment variables GITLAB_ORG_TOKEN and KONFLUX_KUBECONFIG are required to be set."
    echo " "
    echo "options:"
    echo "-h, --help                  Show brief help"
    echo "-d, --dry_run               No actions actually performed, cmds are displayed. Default: false"
    echo "-b, --branch=BRANCH         Specify a base branch name to be used for updates, version and step are appended."
    echo "                                   Default: rhtap-cli-release-<\$VERSION>-<stream or rpa>"
    echo "-o, --org=GITLAB_ORG        Specify GITLAB group or user, Default: releng"
    echo "-r, --repository=REPOSITORY Specify a repository, Default: konflux-release-data"
    echo "-s, --steps=STEPS           Specify a comma separated list of steps, Valid: (stream,rpa,all) Default: all"
    echo "-v, --version=VERSION       Specify version of release as #.# (ex. 1.4), Required"
}

short_opt() {
    local VAR_NAME="$1"
    declare -n VAR_REF="$VAR_NAME"
    shift
    shift 
    if [ $# -gt 0 ] && [[ ! "$1" =~ ^-.* ]] ; then
          VAR_REF=$1
    else
          echo "ERROR: Invalid syntax. Option specified but no $VAR_NAME supplied"
          help_text
          exit 1
    fi
    shift
}

long_opt() {
    local VAR_NAME="$1"
    declare -n VAR_REF="$VAR_NAME"
    shift
    VAR_REF=`echo $1 | sed -e 's/^[^=]*=//g'`
    shift
}

verify_syntax() {
    while test $# -gt 0; do
      case "$1" in
        -h|--help)
          help_text
          exit 0
          ;;
        -b)
          short_opt "BRANCH" $@
          shift 2
          ;;
        --branch=*)
          long_opt "BRANCH" $@
          shift
          ;;
        -o)
          short_opt "GITLAB_ORG" $@
          shift 2
          ;;
        --org=*)
          long_opt "GITLAB_ORG" $@
          shift
          ;;
        -r)
          short_opt "REPOSITORY" $@
          shift 2
          ;;
        --repository=*)
          long_opt "REPOSITORY" $@
          shift
          ;;
        -s)
          shift
          if test $# -gt 0; then
            IFS=',' read -r -a STEPS <<< `echo "${1,,}"`
            for step in "${STEPS[@]}"; do
                if [[ ! " ${VALID_STEPS[*]} " =~ [[:space:]]"${step}"[[:space:]] ]]; then
                    echo "ERROR: Invalid STEP entered"
                    exit 1
                fi
            done
          else
            echo "ERROR: Invalid syntax. Option specified but no STEPS supplied"
            exit 1
          fi
          shift
          ;;
        --steps=*)
          IFS=',' read -r -a STEPS <<< `echo "${1,,}" | sed -e 's/^[^=]*=//g'`
          for step in "${STEPS[@]}"; do
              if [[ ! " ${VALID_STEPS[*]} " =~ [[:space:]]"${step}"[[:space:]] ]]; then
                  echo "ERROR: Invalid STEP entered"
                  exit 1
              fi
          done
          shift
          ;;
       -v)
          short_opt "VERSION" $@
          shift 2
          ;;
        --version*)
          long_opt "VERSION" $@
          shift
          ;;
        -d|--dry_run)
          shift
          dry_run=true
          ;;
        *)
          echo "Error: Invalid command syntax"
          help_text
          exit 1
          ;;
      esac
    done

    # Verify version specified
    if [[ -z "${VERSION}" ]]; then
        echo "ERROR: Version not specified."
        help_text
        exit 1
    fi

    # Verify GITLAB_ORG_TOKEN env var set
    if [[ -z "${GITLAB_ORG_TOKEN}" ]]; then
        echo "ERROR: GITLAB_ORG_TOKEN env variable not set."
        exit 1
    fi

    # Vefify KONFLUX_KUBECONFIG env var set
    if [[ -z "${KONFLUX_KUBECONFIG}" ]]; then
        echo "ERROR: KONFLUX_KUBECONFIG env variable not set."
        exit 1
    fi

}

create_branch() {
    cmd="curl -s -X POST -H \"$AUTH_HEADER\" \"https://gitlab.cee.redhat.com/api/v4/projects/$URI_ENCODED_PATH/repository/branches?branch=$BRANCH&ref=main\""

    # Check if dry run
    if [[ "$dry_run" != "true" ]]; then
        # Not dry run, Create branch
        printf "\nCreating branch '$BRANCH' in repository '$GITLAB_ORG/$REPOSITORY'.\n"
        res=$(eval "$cmd")
        if [ "$(echo $res | jq -r 'has("error")' 2>/dev/null)" == "true" ]; then
            message="$(echo $res | jq -r .error)"
            echo "ERROR: Creating '$BRANCH' - $message"
            exit 1
        elif [ "$(echo $res | jq -r 'has("message")' 2>/dev/null)" == "true" ]; then
            message="$(echo $res | jq -r .message)"
            echo "ERROR: Creating '$BRANCH' - $message"
            exit 1
        fi
        printf "Creation of branch '$BRANCH' in repository '$GITLAB_ORG/$REPOSITORY' - SUCCESSFUL\n\n"
    else
        # Dry run print command
        printf "\nCMD to create branch '$BRANCH' in repository '$GITLAB_ORG/$REPOSITORY'\n"
        echo -e "CMD>: $cmd"
    fi
}

clone_branch() {
    # Create Clone command for new branch
    cmd="git clone --quiet -b $BRANCH https://$AUTH_HEADER@gitlab.cee.redhat.com/$GITLAB_ORG/$REPOSITORY.git /tmp/$BRANCH_DIR 2>&1"

        # Clone branch
        echo "Cloning of '$GITLAB_ORG/$REPOSITORY.git' branch '$BRANCH' into directory '$BRANCH_DIR'"
        res=$(eval "$cmd")

        # Successful clone then fetch latest else fail
        if [ $? -eq 0 ] && [ "$(ls -A /tmp/$BRANCH_DIR 2>/dev/null | wc -l)" -ne 0 ]; then
            echo "Cloning of '$GITLAB_ORG/$REPOSITORY.git' branch '$BRANCH' into directory '$BRANCH_DIR' - SUCCESSFUL"
            cd /tmp/$BRANCH_DIR
            git fetch
        else
            echo "Error: Cloning of $GITLAB_ORG/$REPOSITORY.git failed - $res"
            exit 1
        fi
}

update_file_content() {
    if [[ "$FILE_DIR" == "tenants-config/cluster/stone-prd-rh01/tenants/rhtap-shared-team-tenant" ]]; then
        export STREAM_NAME="rhtap-cli-release-$MOD_VERSION"
        export STREAM_VER="\"$VERSION\""
        export STREAM_BRANCH="\"release-$VERSION\""
        yq -i '.metadata.name = env(STREAM_NAME)' $PATH_TO_FILE
        yq -i '.spec.template.values[0].value = env(STREAM_VER)' $PATH_TO_FILE
        yq -i '.spec.template.values[1].value = env(STREAM_BRANCH)' $PATH_TO_FILE
    elif [[ "$FILE_DIR" == "config/stone-prd-rh01.pg1f.p1/product/ReleasePlanAdmission/rhtap-shared-team" ]]; then
        export RPA_NAME="rhtap-cli-$MOD_VERSION"
        export RPA_VER="\"$VERSION\""
        export RPA_VER_LONG="\"$VERSION.0\""
        export RPA_TS="\"$VERSION.0-{{ timestamp }}\""
        yq -i '.spec.applications[0] = env(RPA_NAME)' $PATH_TO_FILE
        yq -i '.spec.data.releaseNotes.product_version = env(RPA_VER)' $PATH_TO_FILE
        yq -i '.spec.data.mapping.components[0].name = env(RPA_NAME)' $PATH_TO_FILE
        yq -i '.spec.data.mapping.components[0].tags[4] = env(RPA_VER_LONG)' $PATH_TO_FILE
        yq -i '.spec.data.mapping.components[0].tags[5] = env(RPA_TS)' $PATH_TO_FILE
    else
        echo "ERROR: Failed to update $PATH_TO_FILE - No conversion data for file"
    fi
}

update_files() {
    # Loop through FILE_LIST and update files
    echo -e "\nUpdating files in branch $BRANCH for release $VERSION"
    for PATH_TO_FILE in ${FILE_LIST[@]}; do
        # Filename and Directory
        FILE_DIR=$(dirname "$PATH_TO_FILE")
        FILE_NAME=$(basename "$PATH_TO_FILE")

        # Update file content
        update_file_content
    done || exit 1

    echo -e "Update of files in branch $BRANCH for release $VERSION - SUCCESSFUL"
}

run_build_manifests() {
    # Complete modifications by running build-manifest.sh
    echo -e "\nRunning build-manifests.sh"
    ./tenants-config/build-manifests.sh > /dev/null

    if [ $? -ne 0 ]; then
        echo "Error: Running of build-manifests failed"
        exit 1
    fi

    echo "Running of build-manifests.sh - SUCCESSFUL"

    # Pause for 10
    sleep 10
}

get_changes() {
    # Get Untracked files
    IFS=$'\n' read -r -d '' -a UNTRACKED_FILES < <( git ls-files --others --exclude-standard && printf '\0' )

    # Get Deleted files
    IFS=$'\n' read -r -d '' -a DELETED_FILES < <( git diff --name-only --diff-filter D HEAD && printf '\0' )

    # Get Modified files
    IFS=$'\n' read -r -d '' -a MODIFIED_FILES < <( git diff --name-only --diff-filter M HEAD && printf '\0' )

    echo -e  "\nUntracked Files:"
    for item in "${UNTRACKED_FILES[@]}"; do
        echo $item
    done

    echo -e "\nDeleted Files:"
    for item in "${DELETED_FILES[@]}"; do
        echo $item
    done

    echo -e "\nModified Files:"
    for item in "${MODIFIED_FILES[@]}"; do
        echo $item
    done

    if [ -z "${UNTRACKED_FILES[@]}" ] && [ -z "${DELETED_FILES[@]}" ] && [ -z "${MODIFIED_FILES[@]}" ]; then
        echo -e "\nERROR: No changes to merge"
        exit 1
    fi
}

build_commit_cmd() {
    # Commit command
    URI_ENCODED_PATH=$(echo "$GITLAB_ORG/$REPOSITORY" | jq -Rr @uri) 
    ACTIONS=""

    # Build commit actions for Deleted, updated and created files
    # Deleted
    for item in "${DELETED_FILES[@]}"; do
        ACTIONS+=$( cat <<EOF
        {
          "action": "delete",
          "file_path": "$item"
        },
EOF
        )
    done

    # Updated
    for item in "${MODIFIED_FILES[@]}"; do
        CONTENT=$(base64 $item | sed -z 's/\n/\\n/g')
        ACTIONS+=$( cat <<EOF
        {
          "action": "update",
          "file_path": "$item",
          "encoding": "base64",
          "content": "$CONTENT"
        },
EOF
        )
    done

    # Created
    for item in "${UNTRACKED_FILES[@]}"; do
        CONTENT=$(base64 $item | sed -z 's/\n/\\n/g')
        ACTIONS+=$( cat <<EOF
        {
          "action": "create",
          "file_path": "$item",
          "encoding": "base64",
          "content": "$CONTENT"
        },
EOF
        )
    done

    # Remove trailing comma
    ACTIONS=${ACTIONS%?}
 
    # Construct the JSON payload
    DATA=$(cat <<EOF
    '{
      "branch": "$BRANCH",
      "commit_message": "$COMMIT_MESSAGE",
      "actions": [
        $ACTIONS
      ]
    }'
EOF
    )

    # Commit cmd
    COMMIT_CMD="curl -s -X POST -H \"$AUTH_HEADER\" -H \"Content-Type: application/json\" -d $DATA \"https://gitlab.cee.redhat.com/api/v4/projects/$URI_ENCODED_PATH/repository/commits\"" 
}

run_commit_cmd() {
    if [[ "$dry_run" != "true" ]]; then

        printf "\nCommit changes to branch '$BRANCH'\n"
        res=$(eval "$COMMIT_CMD")
        exit_code=$?

        if [ $exit_code -ne 0 ]; then
            if [ "$(echo $res | jq -r 'has("error")' 2>/dev/null)" == "true" ]; then
                message="$(echo $res | jq -r .error)"
                echo "ERROR: Creating commit - $message"
                exit 1
            elif [ "$(echo $res | jq -r 'has("message")' 2>/dev/null)" == "true" ]; then
                message="$(echo $res | jq -r .message)"
                echo "ERROR: Creating commit - $message"
                exit 1
            else
                echo "ERROR: Creating commit - $res"
                exit 1
            fi
        fi
        printf "Commit of changes to branch "$BRANCH" - SUCCESSFUL\n\n"
    else
        # Dry run print command
        printf "\nCMD to create commit and update files\n"
        echo "CMD>: "$COMMIT_CMD
    fi
}

create_mr() {
    CREATE_MR_CMD="curl -s -X POST -H \"$AUTH_HEADER\" -d \"source_branch=$BRANCH\" -d \"target_branch=main\" -d \"title=$COMMIT_MESSAGE\" -d \"description=$DESCRIPTION\" -d \"id=$URI_ENCODED_PATH\" -d \"remove_source_branch=True\" -d \"squash=True\" \"https://gitlab.cee.redhat.com/api/v4/projects/$URI_ENCODED_PATH/merge_requests\""

    if [[ "$dry_run" != "true" ]]; then

        printf "Create MR for '$BRANCH'\n"
        res=$(eval "$CREATE_MR_CMD")
        exit_code=$?

        if [ $exit_code -ne 0 ]; then
            if [ "$(echo $res | jq -r 'has("error")' 2>/dev/null)" == "true" ]; then
                message="$(echo $res | jq -r .error)"
                echo "ERROR: Creating MR - $message"
                exit 1
            elif [ "$(echo $res | jq -r 'has("message")' 2>/dev/null)" == "true" ]; then
                message="$(echo $res | jq -r .message)"
                echo "ERROR: Creating MR - $message"
                exit 1
            else
                echo "ERROR: Creating MR - $res"
                exit 1
            fi
        fi
        printf "Creation of MR - SUCCESSFUL\n\n"

        IID=$(echo $res | jq -r '.iid' 2>/dev/null)
        STATE=$(echo $res | jq -r '.state' 2>/dev/null)
        MERGE_STATUS=$(echo $res | jq -r '.detailed_merge_status' 2>/dev/null)

        echo -e "MR IID: $IID\n"
        COUNT=60
        
        printf "Monitoring merge status\n"
        while [[ "$MERGE_STATUS" != "mergeable" ]]; do
            INDEX=$((60-COUNT+1))
            echo -ne "$INDEX $MERGE_STATUS \r"
            res=$(curl -s -X GET -H "PRIVATE-TOKEN:HwSPosgqDc6Zu8Jtjpxv" "https://gitlab.cee.redhat.com/api/v4/projects/$URI_ENCODED_PATH/merge_requests/$IID")
            IID=$(echo $res | jq -r '.iid' 2>/dev/null)
            STATE=$(echo $res | jq -r '.state' 2>/dev/null)
            MERGE_STATUS=$(echo $res | jq -r '.detailed_merge_status' 2>/dev/null)

            # Make sure mr is open
            if [[ "$MERGE_STATUS" == "not_open" ]]; then
                res=$(curl -s -X PUT -H "PRIVATE-TOKEN:HwSPosgqDc6Zu8Jtjpxv" -d "state_event=open" "https://gitlab.cee.redhat.com/api/v4/projects/$URI_ENCODED_PATH/merge_requests/$IID")
                exit_code=$?
                if [ $exit_code -ne 0 ]; then
                    if [ "$(echo $res | jq -r 'has("error")' 2>/dev/null)" == "true" ]; then
                        message="$(echo $res | jq -r .error)"
                        echo "ERROR: Updating MR - $message"
                        exit 1
                    elif [ "$(echo $res | jq -r 'has("message")' 2>/dev/null)" == "true" ]; then
                        message="$(echo $res | jq -r .message)"
                        echo "ERROR: Updating MR - $message"
                        exit 1
                    else
                        echo "ERROR: Updating MR - $res"
                        exit 1
                    fi
                fi
            fi

            if [[ "MERGE_STATUS" == "not_approved" ]]; then
                res=$(curl -s -X POST -H "$AUTH_HEADER" "https://gitlab.cee.redhat.com/api/v4/projects/$URI_ENCODED_PATH/merge_requests/$IID/approve")
                exit_code=$?
                if [ $exit_code -ne 0 ]; then
                    if [ "$(echo $res | jq -r 'has("error")' 2>/dev/null)" == "true" ]; then
                        message="$(echo $res | jq -r .error)"
                        echo "ERROR: Updating MR - $message"
                        exit 1
                    elif [ "$(echo $res | jq -r 'has("message")' 2>/dev/null)" == "true" ]; then
                        message="$(echo $res | jq -r .message)"
                        echo "ERROR: Updating MR - $message"
                        exit 1
                    else
                        echo "ERROR: Updating MR - $res"
                        exit 1
                    fi
                fi
            fi

            ((COUNT--))
            sleep 10

            if [ $COUNT -eq 0 ]; then
                echo "ERROR: MR did not become 'mergable' in time aloted - $MERGE_STATUS"    
                exit 1
            fi
        done
    else
        # Dry run print command
        printf "\nCMD to create MR\n"
        echo "CMD>: "$CREATE_MR_CMD
    fi
}

merge_mr() {
    MERGE_CMD="curl -s -X PUT -H \"$AUTH_HEADER\" \"https://gitlab.cee.redhat.com/api/v4/projects/$URI_ENCODED_PATH/merge_requests/$IID/merge\""

    if [[ "$dry_run" != "true" ]]; then
        echo "Merge status: $MERGE_STATUS"
        printf "\nMerging MR\n"
        if [[ "$MERGE_STATUS" == "mergeable" ]]; then
            res=$(curl -s -X PUT -H "$AUTH_HEADER" "https://gitlab.cee.redhat.com/api/v4/projects/$URI_ENCODED_PATH/merge_requests/$IID/merge")
            exit_code=$?
            if [ $exit_code -ne 0 ]; then
                if [ "$(echo $res | jq -r 'has("error")' 2>/dev/null)" == "true" ]; then
                    message="$(echo $res | jq -r .error)"
                    echo "ERROR: Merging MR - $message"
                    exit 1
                elif [ "$(echo $res | jq -r 'has("message")' 2>/dev/null)" == "true" ]; then
                    message="$(echo $res | jq -r .message)"
                    echo "ERROR: Merging MR - $message"
                    exit 1
                else
                    echo "ERROR: Merging MR - $res"
                    exit 1
                fi
            fi
            printf "Merging of MR - SUCCESSFUL\n\n"
        else
            echo "ERROR: Unable to merge MR - $MERGE_STATUS"
            exit 1
        fi
    else
        # Dry run print command
        if [ -z "$IID" ]; then
            IID="<IID>"
            MERGE_CMD="curl -s -X PUT -H \"$AUTH_HEADER\" \"https://gitlab.cee.redhat.com/api/v4/projects/$URI_ENCODED_PATH/merge_requests/$IID/merge\""
        fi
        printf "\nCMD to merge MR:\n"
        echo "CMD>: "$MERGE_CMD
    fi
}

check_pipeline_runs() {
    if [ "$TEST" == "false" ]; then
        # Get release object for
        COUNT=60
        EXIT_STATUS=-1
        echo "Obtaining Release Object"
        while [ $EXIT_STATUS -ne 0 ]; do
            RELEASE_OBJ=$(kubectl --kubeconfig=$KONFLUX_KUBECONFIG get release -o custom-columns=:.metadata.name --no-headers | grep -e "rhtap-cli-$MOD_VERSION" | grep Progressing)
            EXIT_STATUS=$?
    
            ((COUNT--))
            sleep 10
            printf "*"

            if [ $COUNT -eq 0 ]; then
                echo -e "\nERROR: Unable to obtain release object"
                exit 1
            fi 
        done
        echo " "
        echo "Obtaining Release Object - SUCCESSFUL"
    fi

    # Get snapshot and pipeline run from RELEASE_OBJ
    SNAPSHOT=$(kubectl --kubeconfig=$KONFLUX_KUBECONFIG get release $RELEASE_OBJ -o custom-columns=:.spec.snapshot --no-headers)
    PIPELINE=$(kubectl --kubeconfig=$KONFLUX_KUBECONFIG get release $RELEASE_OBJ -o custom-columns=:.status.managedProcessing.pipelineRun --no-headers)

    NAMESPACE=$(dirname "$PIPELINE")
    PIPELINE_RUN=$(basename "$PIPELINE")
    
    if [ "$TEST" == "true" ]; then
        NAMESPACE=$TEST_NAMESPACE
        PIPELINE_RUN=$TEST_PIPELINE_RUN   
    fi
 
    REASON="Running"

    printf "Monitoring Pipeline Run\n"
    while [ "$REASON" == "Running" ]; do
        printf "*"
        REASON=$(kubectl --kubeconfig=$KONFLUX_KUBECONFIG get pipelineruns -n $NAMESPACE $PIPELINE_RUN -o custom-columns=:.status.conditions[0].reason --no-headers 2>&1)
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to obtain Release Pipeline: $REASON" 
            exit -1
        fi

        sleep 10
    done
    echo " "

    STATUS=$(kubectl --kubeconfig=$KONFLUX_KUBECONFIG get pipelineruns -n $NAMESPACE $PIPELINE_RUN -o custom-columns=:.status.conditions[0].status --no-headers)

    if [ "$STATUS" == "False" ]; then
        echo "ERROR: Release Pipeline FAILED: Check logs Namespace: $NAMESPACE PipelineRun: $PIPELINE_RUN"
        exit 1
    else
        echo -e "Release Pipeline Run '$PIPELINE_RUN' in Namespace '$NAMESPACE' Succeeded\n"
    fi 
}

check_for_image() {
    if [ "$TEST" == "true" ]; then
        CHECK_VERSION=$TEST_VERSION.0
    else
        CHECK_VERSION=$VERSION.0
    fi

    COUNT=60
    EXIT_STATUS=-1
    echo "Checking for image in registry"
    while [ $EXIT_STATUS -ne 0 ]; do
        IMAGE=$(podman inspect registry.redhat.io/rhtap-cli/rhtap-cli-rhel9:$CHECK_VERSION)
        EXIT_STATUS=$?

        ((COUNT--))
        sleep 10
        printf "*"

        if [ $COUNT -eq 0 ]; then
            echo -e "\nERROR: Unable to find image: $IMAGE"
            echo "Please manually check registry.redhat.io that image is correct" 
            exit 1
        fi
        echo " "
        echo "Update of image in registry - SUCCESSFUL"
    done
}

update_stream() {
    # Update Files for release
    FILE_LIST=$STREAM_LIST
    UNTRACKED_FILES=()
    DELETED_FILES=()
    MODIFIED_FILES=()
    IID=""

    # Check branch cmd
    GET_BRANCH_CMD="curl -s -o /dev/null -I -w \"%{http_code}\" -X GET -H \"$AUTH_HEADER\" \"https://gitlab.cee.redhat.com/api/v4/projects/$URI_ENCODED_PATH/repository/branches/$BRANCH\""

    # Create Clone command for new branch
    BRANCH_DIR="$PREFIX-stream"

    # Create branch
    create_branch

    # Create tmp working directory
    mkdir /tmp/$BRANCH_DIR

    # Check for branch
    res=$(eval "$GET_BRANCH_CMD")

    if [[ "$res" == "200" || "$res" == "201" ]]; then
        # Clone branch
        clone_branch

        update_files

        run_build_manifests

        get_changes
    else
        if [[ "$dry_run" == "true" ]]; then
            # Dry run print command
            printf "\nCMD to clone branch '$BRANCH' from repository '$GITLAB_ORG/$REPOSITORY'\n"
            echo -e "CMD>: $cmd"
        else
            echo "Error: Unable to clone '$BRANCH',  $BRANCH in $GITLAB_ORG/$REPOSITORY.git may not exist"
            exit 1
        fi
    fi

    COMMIT_MESSAGE="Update rhtap-cli-stream for setup of release $VERSION (Automated)"
    DESCRIPTION="<h3>What:</h3>This PR is in prep to onboard rhtap-cli release-$VERSION branch as application rhtap-cli-$MOD_VERSION<br /><h3>Why:</h3>We are preparing for rhtap-cli $VERSION release through rhtap-cli release-$VERSION branch<br />"

    build_commit_cmd

    run_commit_cmd

    create_mr

    merge_mr

    # Check for application
    if [[ "$dry_run" == "false" ]]; then
        COUNT=60
        EXIT_STATUS=-1
        echo "Checking Application rhtap-cli-$MOD_VERSION created"
        while [ $EXIT_STATUS -ne 0 ]; do
            if [ "$TEST" == "true" ]; then
                APP_NAME=$(kubectl --kubeconfig=$KONFLUX_KUBECONFIG get application rhtap-cli-$TEST_MOD_VERSION -o custom-columns=:.metadata.name --no-headers 2>&1)
            else 
                APP_NAME=$(kubectl --kubeconfig=$KONFLUX_KUBECONFIG get application rhtap-cli-$MOD_VERSION -o custom-columns=:.metadata.name --no-headers 2>&1)
            fi
            EXIT_STATUS=$?

            ((COUNT--))
            sleep 10

            if [ $COUNT -eq 0 ]; then
                echo "ERROR: Application rhtap-cli-$MOD_VERSION not present in konflux - $APP_NAME"
                exit 1
            fi
        done
        echo -e "Application rhtap-cli-$MOD_VERSION created - SUCCESSFUL"
    fi
}

update_rpa() {
    # Update Files for release
    FILE_LIST=$RPA_LIST
    UNTRACKED_FILES=()
    DELETED_FILES=()
    MODIFIED_FILES=()
    IID=""

    # Check branch cmd
    GET_BRANCH_CMD="curl -s -o /dev/null -I -w \"%{http_code}\" -X GET -H \"$AUTH_HEADER\" \"https://gitlab.cee.redhat.com/api/v4/projects/$URI_ENCODED_PATH/repository/branches/$BRANCH\""

    # Set BRANCH Directory 
    BRANCH_DIR="$PREFIX-rpa"

    # Create tmp working directory
    mkdir /tmp/$BRANCH_DIR

    # Create branch
    create_branch

    # Check for branch
    res=$(eval "$GET_BRANCH_CMD")

    if [[ "$res" == "200" || "$res" == "201" ]]; then

        # Clone branch
        clone_branch

        update_files

        get_changes
    else
        if [[ "$dry_run" == "true" ]]; then
            # Dry run print command
            printf "\nCMD to clone branch '$BRANCH' from repository '$GITLAB_ORG/$REPOSITORY'\n"
            echo -e "CMD>: $cmd"
        else
            echo "Error: Unable to clone '$BRANCH',  $BRANCH in $GITLAB_ORG/$REPOSITORY.git may not exist"
            exit 1
        fi
    fi

    COMMIT_MESSAGE="release rhtap-cli $VERSION.0 (Automated)"
    DESCRIPTION="<h3>What:</h3>RPA is updated to point to the rhtap-cli $VERSION application and component<br /><h3>Why:</h3>This PR is to release rhtap-cli $VERSION<br />"

    build_commit_cmd

    run_commit_cmd

    create_mr

    merge_mr

    if [[ "$dry_run" == "false" ]]; then 
        check_pipeline_runs
        check_for_image
    fi
}

trap cleanup EXIT
verify_syntax $@

echo "dry_run     : ${dry_run}"
printf -v joined '%s,' "${STEPS[@]}"
echo "STEPS       : ${joined%,}"
echo "GITLAB_ORG  : ${GITLAB_ORG}"
echo "REPOSITORY  : ${REPOSITORY}"
echo "VERSION     : ${VERSION}"

# Set random PREFIX
PREFIX=$(openssl rand -base64 64 | tr -d -c a-zA-Z0-9 | head -c 8)

# Set Modified version #-#
MOD_VERSION=$(echo "$VERSION" | sed -r 's/\./-/g')

# Set the Gitlab Token
export GITLAB_TOKEN="$GITLAB_ORG_TOKEN"

# Headers for authentication
AUTH_HEADER="PRIVATE-TOKEN:$GITLAB_TOKEN"

# URI encoded path to <org|group>/<repository>
URI_ENCODED_PATH=$(echo "$GITLAB_ORG/$REPOSITORY" | jq -Rr @uri)

# BRANCH
if [[ -z "${BRANCH}" ]]; then
    BRANCH_STREAM="rhtap-cli-release-$VERSION-stream"
    BRANCH_RPA="rhtap-cli-release-$VERSION-rpa"
else
    BRANCH_STREAM="${BRANCH}-${VERSION}-stream"
    BRANCH_RPA="${BRANCH}-${VERSION}-rpa"
fi

if [[ " ${STEPS[*]} " =~ [[:space:]]"all"[[:space:]] ]] || [[ " ${STEPS[*]} " =~ [[:space:]]"stream"[[:space:]] ]]; then
    echo -e "\n\n============================ Update Stream for Release ============================\n"
    BRANCH=$BRANCH_STREAM
    echo -e "BRANCH      : ${BRANCH}\n"
    update_stream
    echo "======================= Update Stream for Release Completed ======================="
fi

if [[ " ${STEPS[*]} " =~ [[:space:]]"all"[[:space:]] ]] || [[ " ${STEPS[*]} " =~ [[:space:]]"rpa"[[:space:]] ]]; then
    echo -e "\n\n============================= Update RPA for Release ==============================\n"
    BRANCH=$BRANCH_RPA
    echo -e  "BRANCH      : ${BRANCH}\n"
    update_rpa
    echo "======================== Update RPA for Release Completed ========================="
fi
