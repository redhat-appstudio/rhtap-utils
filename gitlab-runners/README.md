Setting up to use Gitlab runner on OpenShift instead of default runners in GitLab.com.

1. Create namespace: oc new-project gitlab-runner
2. Install GitLab runner operator in cluster in namespace gitlab-runner
3. Create Runner in GitLab.com:
a. Go to Gitlab organization, Click on Build, Click on subemenu Runners, click on create New Group runner, tick on Run untagged jobs, click on create runner and copy token from code snippet - something like "glrt-.....".
3. Replace runner token in gitlab-runner-secret.yml and apply:  oc apply -f gitlab-runner-secret.yml   
4. Create service account: oc apply -f gitlab-ci-sa.yml 
5. Create SCC for service account: oc apply -f gitlab-ci-sa-scc.yml 
6. Create custom config for runner: oc create configmap custom-config-toml --from-file config.toml=custom-config-gitlab-ci.toml -n gitlab-runner
7. Create CRD for runners: oc apply -f gitlab-runner.yml
