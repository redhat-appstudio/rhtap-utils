# RHTAP-CLI release

Consists of the script tssc-konflux.sh that automates the
creation of MR's to add new applicatoin version in konflux and
release new version application through konflux.

NOTE: rhtap-cli-stream.yaml is expected to be in order by version. Oldest version first entry
      in file and new version last entry in file.

## tssc-konflux.sh

Script updates the appropriate files and creates the MR to either add
new application version to konflux or release new version. It is left to
the user to get the MR approved, merged and verify action completes
successfully in konflux.

### Defaults
KEEP_VERSION: 3

### Required Positional Arguments
ACTION required to be set see syntax
VERSION required to be set see syntax

### Syntax
```console
user@machine:~$ ./tssc-konflux.sh -h

Usage:
    tssc-konflux.sh [options] <action=app|release> <version>
       <action> =  Action app ( create application) or release (release application).
       <version> = Application version to create or release on konflux (#.#).

Optional arguments:
    --dry-run
        Do not push updates and create MR to merge into upstream main.
    -d, --debug
        Activate tracing/debug mode.
    -h, --help
        Display this message.
    -k, --keep
        Number of Versions to keep. Default is 3.
    -f, --force
        Set force on push command
    -w, --wip
        Set work in progress, MR will be set as Draft
Example:
    tssc-konflux.sh release 1.7

```

### Execution
1. Run script [./tssc-konflux.sh](./tssc-konflux.sh)

