#!/bin/bash

# Set variables
IMAGE_NAME="jenkins-rhtap"
QUAY_REPO="quay.io/rhtap_qe/$IMAGE_NAME"
DATE_TAG=$(date +'%Y%m%d%H%M')

# Build the image for x64 architecture
podman build --arch x86_64 -t $IMAGE_NAME .

# Tag the image with "latest"
podman tag $IMAGE_NAME $QUAY_REPO:latest

# Tag the image with the current date and time
podman tag $IMAGE_NAME $QUAY_REPO:$DATE_TAG

# Push the "latest" tag to Quay.io
podman push $QUAY_REPO:latest

# Push the date-tagged image to Quay.io
podman push $QUAY_REPO:$DATE_TAG

# Output the tags for verification
echo "Image tagged with:"
echo "$QUAY_REPO:latest"
echo "$QUAY_REPO:$DATE_TAG"