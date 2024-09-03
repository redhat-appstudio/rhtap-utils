RHTAP QE Jenkins Guide
------------------------------------------------------------

# Setup Jenkins on OpenShift 

1. Login to OpenShift
2. Create new project jenkins: oc new-project jenkins
3. Create new build for jenkins agent(with buildah and other utilities for RHTAP pipelines):oc new-build --name jenkins-agent-base  --binary=true --strategy=docker
4. Start new build: oc start-build jenkins-agent-base --from-file=./jenkins-agent/Dockerfile --wait --follow
5. Deploy jenkins from openshift template: oc new-app -e JENKINS_PASSWORD=admin123 -e VOLUME_CAPACITY=10Gi jenkins-persistent 
6. Upload new SecurityContextConstraints for Jenkins agent(for running jenkins agent in privileged mode): oc apply -f ./jenkins-agent/jenkins-agent-base-scc.yml
7. Apply policy to Jenkins user(for running jenkins agent in privileged mode): oc adm policy add-scc-to-user jenkins-agent-base -z jenkins
8. (Optional)You can check if the correct agent image is used and buildah is working by creating new pipeline from file pipeline-buildah
9. Login in the Jenkins instance and lookup for your Jenkins User ID - you can see it when you click on your user on right top corner(like jkopriva@redhat.com-admin-edit-view, cluster-admin-admin-edit-view) and click on Configure and generate API token - you will need, URL, username and token for RHTAP installation, setting creds in Jenkins, running e2e tests
10. You can continue with RHTAP Installation(do not forget to add Jenkins integration with correct parameters: Jenkins URL, username and token)
11. REQUIRED You need to change in jenkins file "agent any" to https://github.com/redhat-appstudio/rhtap-utils/blob/main/jenkins/Jenkinsfile-jenkins-agent(you need to copy whole kubernetes settings)
12. When you are creating a Job in Jenkins it needs to have same name as componnet to be picked up by RHDH

(For Jenkins installation you can also use jenkins-deploy.sh script)

# Setup creadentials for RHTAP Jenkins on OpenShift for testing

1. Check credentials in jenkins-credentials.sh (ACS endpoint, ACS token, GitOps token, Quay username/password) and values for your jenkins instance
2. Run script ./jenkins-credentials.sh
3. (For Gitlab you also need to add GITOPS_AUTH_USERNAME variable)

# Common issues:
 - I do not see Jenkins during creation of component - You have wrong URL to catalog URL, you can change it here: ns/rhtap/secrets/developer-hub-rhtap-env/yaml and kill old developer hub pods and wait for new ones
 - Jenkins Job is failing because some secret like GITOPS_AUTH_PASSWORD is not set(or any other variable) - You need to setup creds in jenkins for example with this file: https://github.com/redhat-appstudio/rhtap-utils/blob/a7e490b2ce4797bba112a08427aa9240e5207a0a/jenkins/jenkins-credentials.sh - or manually
 - Buildah in jenkins job/pipeline does not work - You have not changed agent in Jenkinsfile or the jenkins agent pod does not run in privileged mode
 - Jenkins job status is not reported back to developer hub - You do not have correct credentials for Jenkins in developer hub, update  ns/rhtap/secrets/developer-hub-rhtap-env/yaml with correct creds
 - 'Jenkins' doesn't have label 'jenkins-agent' - You need to setup correct Jenkins agent in your Jenkinsfile and check labels, if they are correct. Verify also Jenkins agent settings in Jenkinsfile.
