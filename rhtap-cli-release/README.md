# RHTAP-CLI release

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

