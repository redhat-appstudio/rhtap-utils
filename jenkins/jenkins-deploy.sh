#!/bin/bash
set -e

oc new-project jenkins
oc new-build --name jenkins-agent-base  --binary=true --strategy=docker
oc start-build jenkins-agent-base --from-file=./jenkins-agent/Dockerfile --wait --follow
oc new-app -e JENKINS_PASSWORD=admin123 -e VOLUME_CAPACITY=10Gi jenkins-persistent 
kubectl -n jenkins wait pod --for=condition=ready=False -l openshift.io/deployer-pod-for.name=jenkins-1 --timeout=120s
oc apply -f ./jenkins-agent/jenkins-agent-base-scc.yml 
oc adm policy add-scc-to-user jenkins-agent-base -z jenkins
 