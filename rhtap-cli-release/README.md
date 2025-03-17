# RHTAP-CLI release

Consists of two scripts (rhtap-cli-release.sh and rhtap-cli-konflux.sh) that automate the
creation of a new release branch, update files that contain release specific information,
and creates and releases the image through konflux.

## rhtap-cli-release.sh

Creates a new release branch in organization and repo specified and
will update a number of files that require release specific information. This script
targets repo rhtap-cli and the files it updates are rhtap-cli specific. NOTE: Though repo may
be overridden it should be a fork or copy of rhtap-cli.

### Defaults
ORG: redhat-appstudio
REPOSITORY: rhtap-cli 
BRANCH: release-<$VERSION>

### Required
`GITHUB_ORG_TOKEN` environment variable must be set
VERSION required to be supplied as input `See Syntax`

### Syntax
```console
user@machine:~$ ./rhtap-cli-release.sh -h
./rhtap-cli-release.sh -h
 
./rhtap-cli-release.sh - Creates new release branch and updates a number
     of files that contain release specific information
 
./rhtap-cli-release.sh [options]
 
Note: Environment variable GITHUB_ORG_TOKEN required to be set.
 
options:
-h, --help                  Show brief help
-d, --dry_run               No actions actually performed, cmds are displayed. Default: false
-b, --branch=BRANCH         Specify a branch to be created, Default: release-<$VERSION>
-o, --org=GITHUB_ORG        Specify GITHUB organization or user, Default: redhat-appstudio
-r, --repository=REPOSITORY Specify a repository, Default: rhtap-cli
-s, --steps=STEPS           Specify a comma separated list of steps, Valid: (branch,update,all) Default: all
-v, --version=VERSION       Specify version of release as #.# (ex. 1.4), Required

```
### Execution

1. Set environment variables `GITHUB_ORG_TOKEN`
2. Run script [./rhtap-cli-release.sh](./rhtap-cli-release.sh)


## rhtap-cli-konflux.sh

Updates rhtap-cli-stream.yaml to add new release application and component to konflux. Then
updates the RPA to complete the release by building and pushing image to registry.redhat.io.
This script targets repo konflux-release-data and the files it updates are konflux-release-data
specific. NOTE: Though repo may be overridden it should be a fork or copy of konflux-release-data.

### Defaults
ORG: releng
REPOSITORY: konflux-release-data
BRANCH: rhtap-cli-release-<$VERSION>-<stream or rpa>

### Required
`GITLAB_ORG_TOKEN` environment variable must be set.
`KONFLUX_KUBECONFIG` environment variable must be set. See <a href="https://docs.google.com/document/d/1fxd-sq3IxLHWWqJM7Evhh9QeSXpqPMfRHHDBzAmT8-k/edit?tab=t.0#heading=h.k9vfdzs9n2dr">RHTAP-CLI Setup On Konflux</a> for more info.
VERSION required to be supplied as input `See Syntax`

### Syntax
```console
user@machine:~$ ./rhtap-cli-konflux.sh -h

./rhtap-cli-konflux.sh - Automates the release process of a new rhtap-cli
     version through konflux by updating rhtap-cli-stream and
     the RPA

./rhtap-cli-konflux.sh [options]

Note: Environment variables GITLAB_ORG_TOKEN and KONFLUX_KUBECONFIG are required to be set.

options:
-h, --help                  Show brief help
-d, --dry_run               No actions actually performed, cmds are displayed. Default: false
-b, --branch=BRANCH         Specify a base branch name to be used for updates, version and step are appended.
                                   Default: rhtap-cli-release-<$VERSION>-<stream or rpa>
-o, --org=GITLAB_ORG        Specify GITLAB group or user, Default: releng
-r, --repository=REPOSITORY Specify a repository, Default: konflux-release-data
-s, --steps=STEPS           Specify a comma separated list of steps, Valid: (stream,rpa,all) Default: all
-v, --version=VERSION       Specify version of release as #.# (ex. 1.4), Required
-c, --command=START_CMD     Specify command to start first step at. Used for rerun after failure.
                                   Valid: (branch,update,commit,mr,merge,check,check_image) Default: all
```
### Execution
1. Set environment variables `GITHUB_ORG_TOKEN` and `KONFLUX_KUBECONFIG`
2. Run script [./rhtap-cli-konflux.sh](./rhtap-cli-konflux.sh)

