# RHTAP QE Jenkins Guide

## Setup Jenkins on OpenShift

1. Login to OpenShift
2. `cd` to the directory that contains this README
3. Run the [./jenkins-deploy.sh](./jenkins-deploy.sh) script
4. (Optional) You can check if the pipeline uses the correct agent image and whether buildah is working
    - In your Jenkins instance, click `+ New Item` and create a `Pipeline` style project
    - Use the content of the [pipeline-buildah](./pipeline-buildah) file as the pipeline script
    - Save the pipeline and trigger a new build. It should succeed and print the buildah help message
5. Login in the Jenkins instance and get your username and token
    - You can see the username when you click on your user in the top right corner (like `jkopriva@redhat.com-admin-edit-view`, `cluster-admin-admin-edit-view`)
    - In the user menu, click on `Configure` and generate an API token
    - You will need the username and token for RHTAP installation, setting creds in Jenkins, running e2e tests
6. You can continue with RHTAP Installation (do not forget to add Jenkins integration with correct parameters: Jenkins URL, username and token)
7. REQUIRED In your Jenkinsfile, change `agent any` to the content of [Jenkinsfile-jenkins-agent](./Jenkinsfile-jenkins-agent) (you need to copy the whole kubernetes settings)
    - (Option A) You can build your own image on cluster, where you run the Jenkins, then you can use [Dockerfile](./jenkins-agent/Dockerfile) 
    - (Option B) You can replace the image in `image-registry.openshift-image-registry.svc:5000/jenkins/jenkins-agent-base:latest` in [Jenkinsfile-jenkins-agent](./Jenkinsfile-jenkins-agent) to          `quay.io/jkopriva/rhtap-jenkins-agent:0.1`
9. When you are creating a Job in Jenkins, it needs to have same the same name as the corresponding component to make RHDH associate them

## Setup credentials for RHTAP Jenkins on OpenShift for testing

1. Check credentials in [jenkins-credentials.sh](./jenkins-credentials.sh) (ACS endpoint, ACS token, GitOps token, Quay username/password) and values for your jenkins instance
2. Run script [./jenkins-credentials.sh](./jenkins-credentials.sh)
3. (For Gitlab you also need to add the `GITOPS_AUTH_USERNAME` variable)

## Common issues

 - I do not see Jenkins during creation of component - You have wrong URL to catalog URL, you can change it here: `ns/rhtap/secrets/developer-hub-rhtap-env/yaml` and kill old developer hub pods and wait for new ones
 - Jenkins Job is failing because some secret like `GITOPS_AUTH_PASSWORD` is not set(or any other variable) - You need to setup creds in jenkins for example with this file: [jenkins-credentials.sh](./jenkins-credentials.sh) - or manually
 - Buildah in jenkins job/pipeline does not work - You have not changed agent in Jenkinsfile or the jenkins agent pod does not run in privileged mode
 - Jenkins job status is not reported back to developer hub - You do not have correct credentials for Jenkins in developer hub, update `ns/rhtap/secrets/developer-hub-rhtap-env/yaml` with correct creds
 - 'Jenkins' doesn't have label 'jenkins-agent' - You need to setup correct Jenkins agent in your Jenkinsfile and check labels, if they are correct. Verify also Jenkins agent settings in Jenkinsfile.
 - `error: error processing template "openshift/jenkins-persistent": the namespace of the provided object does not match the namespace sent on the request`
   when running `oc new-app` - your `oc` version may be out of date, try downloading the latest version
