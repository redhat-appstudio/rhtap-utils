#!/bin/bash
set -e

# Create new project 'jenkins'
oc new-project jenkins
# Create new build for jenkins agent (with buildah and other utilities for RHTAP pipelines)
oc new-build --name jenkins-agent-base  --binary=true --strategy=docker
# Start new build
oc start-build jenkins-agent-base --from-file=./jenkins-agent/Dockerfile --wait --follow
# Deploy jenkins from openshift template
oc new-app -e JENKINS_PASSWORD=admin123 -e VOLUME_CAPACITY=10Gi jenkins-persistent

sleep 15  # it could take some time, until jenkins pod is created

# Upload new SecurityContextConstraints for Jenkins agent (for running jenkins agent in privileged mode)
oc apply -f ./jenkins-agent/jenkins-agent-base-scc.yml
# Apply policy to Jenkins user (for running jenkins agent in privileged mode)
oc adm policy add-scc-to-user jenkins-agent-base -z jenkins
