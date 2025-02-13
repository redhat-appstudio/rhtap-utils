#!/bin/bash -e

# Set dry_run to true to not execute commands. It will display curl cmds to
#     create a branch and commits to update files
dry_run="${dry_run:-false}"
REPOSITORY="${REPOSITORY:-rhtap-cli}"
GITHUB_ORG="${GITHUB_ORG:-redhat-appstudio}"
VALID_STEPS=("all" "branch" "update")
STEPS=("all")

cleanup() {
    if [ -v "PREFIX" ] && [ -n "$PREFIX" ]; then
        rm -f /tmp/$PREFIX-*
    fi
}

help_text() {
    echo " "
    echo "$0 - Creates new release branch and updates a number"
    echo "     of files that contain release specific information"
    echo " "
    echo "$0 [options]"
    echo " "
    echo "Note: Environment variable GITHUB_ORG_TOKEN required to be set."
    echo " "
    echo "options:"
    echo "-h, --help                  Show brief help"
    echo "-d, --dry_run               No actions actually performed, cmds are displayed. Default: false"
    echo "-b, --branch=BRANCH         Specify a branch to be created, Default: release-<\$VERSION>"
    echo "-o, --org=GITHUB_ORG        Specify GITHUB organization or user, Default: redhat-appstudio"
    echo "-r, --repository=REPOSITORY Specify a repository, Default: rhtap-cli"
    echo "-s, --steps=STEPS           Specify a comma separated list of steps, Valid: (branch,update,all) Default: all"
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
        --branch*)
          long_opt "BRANCH" $@
          shift
          ;;
        -o)
          short_opt "GITHUB_ORG" $@
          shift 2
          ;;
        --org*)
          long_opt "GITHUB_ORG" $@
          shift
          ;;
        -r)
          short_opt "REPOSITORY" $@
          shift 2
          ;;
        --repository*)
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
        --steps*)
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

    # Verify GITHUB_ORG_TOKEN env var set
    if [[ -z "${GITHUB_ORG_TOKEN}" ]]; then
        echo "ERROR: GITHUB_ORG_TOKEN env variable not set."
        exit 1
    fi

    #echo "Remaining arguments: $@"
}

create_branch() {
    # Get references for repo 
    refs=$(curl -s -X GET -H "$AUTH_HEADER" "https://api.github.com/repos/$GITHUB_ORG/$REPOSITORY/git/refs/heads?per_page=100")
    if [ "$(echo $refs | jq -r .status 2>/dev/null)" ]; then
        message="$(echo $refs | jq -r .message)"
        echo "ERROR Fetching refs - $message"
        exit 1
    fi

    # Get reference info for main 
    echo "$refs" | jq -c '.[]' | while read -r entry; do

        # Searching for refs/heads/main
        if [ "$(echo $entry | jq -r '.ref')" == "refs/heads/main" ]; then

            # Found, Set ref, sha and data
            ref=$(echo $entry | jq -r '.ref')
            sha=$(echo $entry | jq -r '.object.sha')
            echo "SOURCE REF : $ref   SHA: $sha" 
            data="'{\"ref\":\"refs/heads/$BRANCH\",\"sha\":\"$sha\"}'"

            # Build Post command to create branch
            cmd="curl -s -X POST -H \"$AUTH_HEADER\" \"https://api.github.com/repos/$GITHUB_ORG/$REPOSITORY/git/refs\" -d $data"

            # Check if dry run
            if [[ "$dry_run" != "true" ]]; then
            
                # Not dry run, Create branch
                printf "\nCreating branch '$BRANCH' in repository '$GITHUB_ORG/$REPOSITORY'.\n"
                res=$(eval "$cmd")

                # Check for error
                if [ "$(echo $res | jq -r 'has("status")' 2>/dev/null)" == "true" ]; then
                    message="$(echo $res | jq -r .message)"
                    echo "ERROR Creating Branch - $message"
                    exit 1
                fi

                printf "Creation of branch '$BRANCH' in repository '$GITHUB_ORG/$REPOSITORY' - SUCCESSFUL\n\n"
            else
                # Dry run print command
                printf "\nCMD to create branch '$BRANCH' in repository '$GITHUB_ORG/$REPOSITORY'\n"
                echo "CMD: $cmd"
            fi
            break
        fi
    done || exit 1
}

update_file_content() {
    UPDATE_FILE=/tmp/$PREFIX-$FILE_NAME

    if [[ "$FILE_DIR" == ".tekton" ]]; then
        sed -i 's/target_branch == ".*"/target_branch == "release-'"$VERSION"'"/' $UPDATE_FILE
        sed -i "s/appstudio\.openshift\.io\/application\: rhtap\-cli.*/appstudio\.openshift\.io\/application\: rhtap-cli-release-$MOD_VERSION/" $UPDATE_FILE
        sed -i "s/appstudio\.openshift\.io\/component\: rhtap\-cli.*/appstudio\.openshift\.io\/component\: rhtap-cli-release-$MOD_VERSION/" $UPDATE_FILE
    elif [[ "$FILE_DIR" == "installer" ]]; then
        sed -i "s/redhat-appstudio\/tssc-sample-templates\/blob\/.*\/all.yaml/redhat-appstudio\/tssc-sample-templates\/blob\/v$VERSION.0\/all.yaml/" $UPDATE_FILE
    else
        echo "ERROR: Failed to update $PATH_TO_FILE - No conversion data for file"
    fi
}

update_files() {
    # Update Files for release
    FILE_LIST=(".tekton/rhtap-cli-push.yaml" ".tekton/rhtap-cli-pull-request.yaml" "installer/config.yaml")
    PREFIX=$(openssl rand -base64 64 | tr -d -c a-zA-Z0-9 | head -c 8)
    MOD_VERSION=$(echo "$VERSION" | sed -r 's/\./-/g')

    # Loop through FILE_LIST and update files
    for PATH_TO_FILE in ${FILE_LIST[@]}; do

        # Filename and Directory
        FILE_DIR=$(dirname "$PATH_TO_FILE")
        FILE_NAME=$(basename "$PATH_TO_FILE")

        # Get file information
        ref=$(curl -s -X GET -H "$AUTH_HEADER" "https://api.github.com/repos/$GITHUB_ORG/$REPOSITORY/contents/$PATH_TO_FILE?ref=$BRANCH")

        # Check for error
        if [ "$(echo $ref | jq -r 'has("status")' 2>/dev/null)" == "true" ]; then
            if [[ "$dry_run" != "true" ]]; then
                message="$(echo $ref | jq -r .message)"
                echo "ERROR Fetching $PATH_TO_FILE - $message"
            else
                printf "\nINFO: Branch does not exist, No commit/update commands will be displayed\n" 
            fi
            exit 1 
        fi

        # Save SHA and Content
        SHA=$(echo $ref | jq -r '.sha' 2>/dev/null)
        echo $ref | jq -r '.content' > /tmp/$PREFIX-content.txt

        # Decode content
        base64 -d /tmp/$PREFIX-content.txt > /tmp/$PREFIX-$FILE_NAME
        # Save original content file
        cp /tmp/$PREFIX-$FILE_NAME /tmp/$PREFIX-$FILE_NAME.sav

        # Update file content
        update_file_content

        # Convert content to base64
        CONTENT=$(base64 $UPDATE_FILE | sed -z 's/\n/\\n/g')

        # Create data for commit
        DATA="'{\"message\":\"Chore: Updated $FILE_NAME to align with release-$VERSION\",\"content\":\"$CONTENT\",\"branch\":\"$BRANCH\",\"sha\":\"$SHA\"}'"

        # Create curl cmd
        cmd="curl -s -X PUT -H \"$AUTH_HEADER\" -H \"Accept: application/vnd.github+json\" \"https://api.github.com/repos/$GITHUB_ORG/$REPOSITORY/contents/$PATH_TO_FILE\" -d $DATA"

        # Check if dry run
        if [[ "$dry_run" != "true" ]]; then

            # Commit file if there are changes
            if cmp -s /tmp/$PREFIX-$FILE_NAME.sav $UPDATE_FILE; then
                echo "INFO: File already updated not commiting file $PATH_TO_FILE"
            else
                # Not dry run, create commit to update file
                echo "Creating commit to update file $PATH_TO_FILE"
                res=$(eval "$cmd")

                # Check for errors
                if [ "$(echo $res | jq -r 'has("status")' 2>/dev/null)" == "true" ]; then
                    message="$(echo $res | jq -r .message)"
                    echo "ERROR Creating commit for $PATH_TO_FILE - $message"
                    exit 1
                fi

                printf "Creation of commit to update file $PATH_TO_FILE - SUCCESSFUL\n\n"
            fi
        else
            # Dry run print command
            printf "\nCommand to create commit and update file $PATH_TO_FILE\n"
            echo "CMD: $cmd"
        fi

    done || exit 1
}

trap cleanup EXIT
verify_syntax $@

BRANCH="${BRANCH:-release-$VERSION}"

echo "dry_run    : ${dry_run}"
printf -v joined '%s,' "${STEPS[@]}"
echo "STEPS      : ${joined%,}"
echo "GITHUB_ORG : ${GITHUB_ORG}"
echo "REPOSITORY : ${REPOSITORY}"
echo "BRANCH     : ${BRANCH}"
echo "VERSION    : ${VERSION}"

# Set the GitHub Token
export GITHUB_TOKEN="$GITHUB_ORG_TOKEN"

# Headers for authentication
AUTH_HEADER="Authorization: token $GITHUB_TOKEN"

if [[ " ${STEPS[*]} " =~ [[:space:]]"all"[[:space:]] ]] || [[ " ${STEPS[*]} " =~ [[:space:]]"branch"[[:space:]] ]]; then
    create_branch
fi

if [[ " ${STEPS[*]} " =~ [[:space:]]"all"[[:space:]] ]] || [[ " ${STEPS[*]} " =~ [[:space:]]"update"[[:space:]] ]]; then
    update_files
fi

