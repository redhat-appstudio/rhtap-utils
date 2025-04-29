# RHTAP Service Cluster Jenkins Cleanup

Cleaning up Jenkins job directories created from test which have no builds run in the past X number
of days (Default: 14). The script has option to dry run for getting the list of directories that will be deleted without deleting them.

### Manual Cleanup

1. Set environment variable `JENKINS_API_TOKEN`
   Must also set environment variables `JENKINS_USERNAME` and `JENKINS_URL`
       if not using defaults of 'cluster-admin-admin-edit-view' and 'https://jenkins-jenkins.apps.rosa.rhtap-services.xmdt.p3.openshiftapps.com'
2. Run script [./service-jenkins-cleanup.sh](./service-jenkins-cleanup.sh)

### Setup CronJob for cleanup in Konflux

1. Add cronjob.yml to tenants-config/cluster/stone-prd-rh01/tenants/rhtap-shared-team-tenant/periodics. Named appropriately
2. Add it to kustomization.yaml in tenants-config/cluster/stone-prd-rh01/tenants/rhtap-shared-team-tenant/periodics
3. Update README.md with cronjob info in tenants-config/cluster/stone-prd-rh01/tenants/rhtap-shared-team-tenant/periodics

### Set CronJob for regular cleanup in cluster

1. Login to OpenShift cluster where cronjob needs to be setup.
2. (Optional) Update Namespace value in [resources.yaml](./resources.yaml) if required. Default is set to `rhtap-cleanup`
3. Provide the service jenkins credentials `JENKINS_USERNAME`, `JENKINS_API_TOKEN` and `JENKINS_URL` for Secret resource in [resources.yaml](./resources.yaml)
4. (Optional) Update schedule value for CronJob resource in [resources.yaml](./resources.yaml). Default is set to run every Saturday 7:00 AM
5. Create resources for setting CronJob by running: `oc apply -f resources.yaml`
