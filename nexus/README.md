# Install Nexus repository on openshift cluster

## Install Nexus on Openshift

1. Login to OpenShift

2. Deploy Nexus on Openshift

```
$ kubectl apply -k nexus/
```

## Setup Registry

1. Login to Nexus console with the following url
```
$ echo "http://$(kubectl -n nexus get route nexus-web -o 'jsonpath={.spec.host}')"
```
username is `admin`,  The password can be found in the `/nexus-data/admin.password` file in the nexus pod.

2. Click on Settings -> repository -> Create repository and choose docker (hosted) repository. 

3. Provide the port number `8082` for HTTP and enable the `Docker v1 api` and click on `save` at the bottom of the page.

4. Go to the `Realms` on the left navigation bar and click on `Docker bearer token` and save the settings.