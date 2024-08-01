RHTAP QE Jenkins Guide
------------------------------------------------------------

# Setup Jenkins on OpenShift 
WIP - Buildah is not working in image

1. Login to OpenShift
2. Create new project jenkins: oc create -f jenkins-project.yaml
3. Create image stream: oc create -f jenkins-rhtap-image-stream.yaml
4. Update image stream to update periodically(you need to have access to image streams - admin for example has access): oc tag quay.io/rhtap_qe/jenkins-rhtap:latest jenkins-rhtap:latest --scheduled
5. Apply template: oc create -f jenkins-rhtap-openshift.yaml - this will create all resources for Jenkins(template is from OpenShift templates with only change in image and storage size)
5. Login to Jenkins(look in the rotes in the jenkins openshift project) and generate API token for testing(use this token in RHTAP installation/tests), URL looks like: https://jenkins-jenkins.apps.rosa.zucjw-vgyvo-byt.b1e7.p3.openshiftapps.com/

# Build image for RHTAP Jenkins on OpenShift
(We need to have tools for running the pipelines for RHTAP: tree, buildah, cosign, syft)

1. Run script ./build-push-image.sh

# Setup creadentials for RHTAP Jenkins on OpenShift for testing

1. Check credentials in jenkins-credentials.sh (ACS endpoint, ACS token, GitOps token, Quay username/password)
2. Run script ./jenkins-credentials.sh