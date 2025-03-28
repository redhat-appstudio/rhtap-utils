# RHTAP Service Cluster Jenkins Cleanup

Cleaning up Jenkins job directories created from test which have no activity in the past X number
of days (Default: 14). The script has option to dry run for getting the list of directories that will be deleted without deleting them.

### Manual Cleanup

1. Set environment variable `JENKINS_API_TOKEN` and `SERVICE_CLUSTER_PASSWORD`
   Must also set environment variables `JENKINS_USERNAME`, `JENKINS_URL`, `SERVICE_CLUSTER_USER` and `SERVICE_CLUSTER_URL`
       if not using defaults of 'cluster-admin-admin-edit-view', 'https://jenkins-jenkins.apps.rosa.rhtap-services.xmdt.p3.openshiftapps.com',
       'cluster-admin' and 'https://api.rhtap-services.xmdt.p3.openshiftapps.com:443'
2. Run script [./service-jenkins-cleanup.sh](./service-jenkins-cleanup.sh)

### Setup CronJob for cleanup in Konflux

1. Add Service Cluster password to vault. Refer to Doc
2. Add cronjob.yml to tenants-config/cluster/stone-prd-rh01/tenants/rhtap-shared-team-tenant/periodics. Named appropriately
3. Add it to kustomization.yaml in tenants-config/cluster/stone-prd-rh01/tenants/rhtap-shared-team-tenant/periodics
4. Update README.md with cronjob info in tenants-config/cluster/stone-prd-rh01/tenants/rhtap-shared-team-tenant/periodics

### Set CronJob for regular cleanup in cluster

1. Login to OpenShift cluster where cronjob needs to be setup.
2. (Optional) Update Namespace value in [resources.yaml](./resources.yaml) if required. Default is set to `rhtap-cleanup`
3. Provide the service cluster credentials `SERVICE_CLUSTER_USER`, `SERVICE_CLUSTER_PASSWORD and `SERVICE_CLUSTER_URL` for Secret resource in [resources.yaml](./resources.yaml)
4. (Optional) Update schedule value for CronJob resource in [resources.yaml](./resources.yaml). Default is set to run every Saturday 7:00 AM
5. Create resources for setting CronJob by running: `oc apply -f resources.yaml`
