#!/bin/bash

# Set dry_run to true for not deleting jenkins job directories, it will provide list of directories/job to delete
dry_run="${dry_run:-true}"

# Set verbose add info displayed
VERBOSE="${verbose:-false}"

# Last modification should be old than this number of DAYS
DAYS="${DAYS:-14}"

# Set SERVICE_CLUSTER_URL, SERVICE_CLUSTER_USRE, SERVICE_CLUSTER_PASSWORD and KUBECONFIG
export CLUSTER_URL="${SERVICE_CLUSTER_URL:-https://api.rhtap-services.xmdt.p3.openshiftapps.com:443}"
export CLUSTER_PASSWORD="${SERVICE_CLUSTER_PASSWORD}"
export CLUSTER_USER="${SERVICE_CLUSTER_USER:-cluster-admin}"
export JENKINS_API_TOKEN="${JENKINS_API_TOKEN}"
export JENKINS_URL="${JENKINS_URL:-https://jenkins-jenkins.apps.rosa.rhtap-services.xmdt.p3.openshiftapps.com}"
export JENKINS_USERNAME="${JENKINS_USERNAME:-cluster-admin-admin-edit-view}"
export KUBECONFIG=/tmp/.kube/config

help_text() {
    echo " "
    echo "$0 - Cleans up old job directories that have not been updated"
    echo "     in X number of days"
    echo " "
    echo "$0 [options]"
    echo " "
    echo "Note: Environment variables SERVICE_CLUSTER_PASSWORD and JENKINS_API_TOKEN are required to be set."
    echo "      Must set environment variables JENKINS_USERNAME, JENKINS_URL, SERVICE_CLUSTER_USER and SERVICE_CLUSTER_URL"
    echo "           if not using defaults of 'cluster-admin-admin-edit-view',"
    echo "           'https://jenkins-jenkins.apps.rosa.rhtap-services.xmdt.p3.openshiftapps.com', 'cluster-admin' and"
    echo "           'https://api.rhtap-services.xmdt.p3.openshiftapps.com:443'" 
    echo " "
    echo "options:"
    echo "-h, --help                  Show brief help"
    echo "-d, --dry_run=dry_run       No actions actually performed, List of directories to remove. Valid values ['true', 'false'] Default: true"
    echo "-o, --older=DAYS            Specify number of days old directories last modified, Default: 14"
    echo "-v, --verbose               Will output info about skipping directories that sub-diretory has been modified. Default: false"
}

short_opt() {
    local VAR_NAME="$1"
    declare -n VAR_REF="$VAR_NAME"
    shift
    shift
    if [ $# -gt 0 ] && [[ ! "$1" =~ ^-.* ]] ; then
          VAR_REF=$1
    else
          echo "ERROR: Invalid syntax. Option specified but no $VAR_NAME value supplied"
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
        -o)
          short_opt "DAYS" $@
          shift 2
          ;;
        --older*)
          long_opt "DAYS" $@
          shift
          ;;
        -v|--verbose)
          shift
          VERBOSE=true
          ;;
        -d)
          short_opt "dry_run" $@
          shift 2
          ;;
        --dry_run*)
          long_opt "dry_run" $@
          shift
          ;;
        *)
          echo "Error: Invalid command syntax"
          help_text
          exit 1
          ;;
      esac
    done

    if [[ "$dry_run" != "true" ]] && [[ "$dry_run" != "false" ]]; then
        echo "Error: -d/--dry_run must be set to 'true' or 'false'"
        exit 1
    fi

    # Verify creds specified
    if [[ -z "${CLUSTER_PASSWORD}" ]]; then
        echo "ERROR: SERVICE_CLUSTER_PASSWORD must be set."
        exit 1
    fi

    if [[ -z "${JENKINS_API_TOKEN}" ]]; then
        echo "ERROR: JENKINS_API_TOKEN must be set."
        exit 1
    fi
}

get_jenkins_pod() {
    # Get running Jenkins pod
    jenkins_pod=`kubectl get pod -n jenkins -l name=jenkins --field-selector status.phase=Running -o jsonpath="{.items[0].metadata.name}"`
    if [ $? != 0 ]; then
        echo "Error: Unable to obtain running jenkins pod"
        exit 1
    fi
}


run_cmd_on_pod() {
    cmd_results=""

    retries=4
    delay=300

    while [ $retries -gt 0 ]; do
        cmd_results=$(kubectl exec --namespace=jenkins ${jenkins_pod} -- bash -c "${CMD}")
        if [ $? -eq 0 ]; then
            break # Exit loop if successful
        else
            echo "WARNING: Command failed, retrying in $delay seconds..."
            sleep $delay
            retries=$((retries - 1))
        fi
    done

    if [ $retries -eq 0 ]; then
        echo "ERROR: Failed to run '$CMD' on $jenkins_pod after multiple retries."
        exit 1
    fi
}


verify_syntax $@

echo "dry_run    : ${dry_run}"
echo "verbose    : ${VERBOSE}"
echo "DAYS       : ${DAYS}"
echo " "

# Create temp KUEBCONFIG file
mkdir /tmp/.kube
if [ $? != 0 ]; then
    echo "Error: Failed to create directory"
    exit 1
fi

touch $KUBECONFIG
if [ $? != 0 ]; then
    echo "Error: Failed to create KUBECONFIG file - $KUBECONFIG"
    exit 1
fi

# Logon to service cluster
oc login $CLUSTER_URL --username $CLUSTER_USER --password $CLUSTER_PASSWORD
if [ $? != 0 ]; then
    echo "Error: Unable to login to SERVICE CLUSTER: ${CLUSTER_URL}"
    exit 1
fi

get_jenkins_pod
echo " "
echo -e "Jenkins Pod: $jenkins_pod\n"

# Get list of top level jobs directories that have not been modified in over X number of days
CMD='find ${JENKINS_HOME}/jobs -maxdepth 1 -type d -mtime +'${DAYS}' -print'
run_cmd_on_pod
mapfile -d ' ' dir_list < <(printf "$cmd_results")

# Go though and make sure no subdirectories have ben modified.
for check_dir in ${dir_list[@]}; do
    CMD="find ${check_dir} -type d -mtime -${DAYS} -print"
    run_cmd_on_pod
    mapfile -d ' ' check_list < <(printf "$cmd_results")
 
    JOB_NAME=$(basename "$check_dir")
    JOB_URL="$JENKINS_URL/job/$JOB_NAME/"

    # Check if updates
    if [ ${#check_list[@]} == 0 ]; then
        # No updates delete dir
        if [[ "$dry_run" != "true" ]]; then

            echo "Deleting $JOB_NAME"

            curl -s -X POST -u "$JENKINS_USERNAME:$JENKINS_API_TOKEN" "${JOB_URL}doDelete"
        else
            CMD="stat -c '%.19y' ${check_dir}"
            run_cmd_on_pod
            echo -e "Delete $JOB_NAME\t ${cmd_results}"
        fi
        echo " "
    else
        if [[ "$VERBOSE" == "true" ]]; then
            echo "Skipping $JOB_NAME - Subdirectories have recently been modified:"
            for sub_dir in ${check_list[@]}; do
                CMD="stat -c '%.19y' ${sub_dir}"
                run_cmd_on_pod
                echo -e "    ${sub_dir}\t ${cmd_results}"
            done
            echo " "
        fi
    fi
done

