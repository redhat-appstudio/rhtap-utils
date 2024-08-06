RHTAP QE Jenkins Guide
------------------------------------------------------------

# Setup Jenkins on OpenShift 
WIP - Buildah is not working in image

1. Login to OpenShift
2. Create new project jenkins: oc new-project jenkins
3. Create new build for jenkins agent(with buildah and other utilities for RHTAP pipelines):oc new-build --name jenkins-agent-base  --binary=true --strategy=docker
4. Start new build: oc start-build jenkins-agent-base --from-file=./jenkins-agent/Dockerfile --wait --follow
5. Deploy jenkins from openshift template: oc new-app -e JENKINS_PASSWORD=admin123 -e VOLUME_CAPACITY=10Gi jenkins-persistent 
6. oc apply -f ./jenkins-agent/jenkins-agent-base-scc.yml 
7. oc adm policy add-scc-to-user jenkins-agent-base -z jenkins
8. (Optional)You can check if the correct agent image is used and buildah is working by creating new pipeline from file pipeline-buildah
9. Login in the Jenkins instance and lookup for your Jenkins User ID - you can see it when you click on your user on right top corner(like jkopriva@redhat.com-admin-edit-view, cluster-admin-admin-edit-view) and click on Configure and generate API token - you will need, URL, username and token for RHTAP installation, setting creds in Jenkins, running e2e tests
10. You can continue with RHTAP Installation
11. REQUIRED You need to change in jenkins file agent any to jenkins-agent - example in Jenkinsfile-jenkins-agent

# Setup creadentials for RHTAP Jenkins on OpenShift for testing

1. Check credentials in jenkins-credentials.sh (ACS endpoint, ACS token, GitOps token, Quay username/password) and values for your jenkins instance
2. Run script ./jenkins-credentials.sh