# Install Artifactory(JFrog Container Registry) on openshift cluster

1. Login to OpenShift

2. Deploy Artifactory on Openshift

```
$ helm repo add jfrog https://charts.jfrog.io
$ helm repo update
$ helm upgrade --install jfrog-container-registry jfrog/artifactory-jcr  --set artifactory.nginx.enabled=false --namespace artifactory-jcr -f values.yaml --create-namespace

$ oc -n artifactory-jcr create route edge artifactory-web --service=jfrog-container-registry-artifactory --port=http-router
$ oc -n artifactory-jcr create route edge artifactory --service=jfrog-container-registry-artifactory --port=http-artifactory
```
