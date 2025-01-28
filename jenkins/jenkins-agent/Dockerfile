FROM golang:1.23.3 AS build

WORKDIR /src

# Verify Go installation
RUN go version

# Set up environment for Syft build
ENV GO111MODULE=on
ENV CGO_ENABLED=1

# Clone the Syft repository and build using make
RUN git clone https://github.com/redhat-appstudio/rh-syft && \ 
    cd rh-syft && \
    git checkout redhat-latest && \
    ls -all && \
    /src/rh-syft/build-syft-binary.sh

FROM registry.redhat.io/openshift4/ose-jenkins-agent-base

WORKDIR /tmp

COPY --from=build /src/rh-syft/dist/syft /usr/local/bin/syft

ENV _BUILDAH_STARTED_IN_USERNS="" \
    BUILDAH_ISOLATION=chroot \
    STORAGE_DRIVER=vfs

USER root

RUN adduser -g 0 -u 1001 jenkins && \
    yum -y update && \
    yum install -y --setopt=tsflags=nodocs podman skopeo buildah --exclude container-selinux && \
    yum clean all && \
    chown -R jenkins:0 /home/jenkins && \
    chmod -R 775 /home/jenkins && \
    chmod -R 775 /etc/alternatives && \
    chmod -R 775 /var/lib/alternatives && \
    chmod -R 775 /usr/lib/jvm && \
    chmod -R 775 /usr/bin && \
    chmod 775 /usr/share/man/man1 && \
    mkdir -p /var/lib/origin && \
    chmod 775 /var/lib/origin && \
    chmod u-s /usr/bin/new[gu]idmap && \
    setcap cap_setuid+eip /usr/bin/newuidmap && \
    setcap cap_setgid+eip /usr/bin/newgidmap && \
    rm -f /var/logs/*



# Download and install tree RPM package tree  
RUN curl -sL https://vault.centos.org/8.5.2111/BaseOS/x86_64/os/Packages/tree-1.7.0-15.el8.x86_64.rpm -o /tmp/tree.rpm && \
    yum localinstall -y /tmp/tree.rpm && \
    rm -f /tmp/tree.rpm

# Install yq (YAML processor)
RUN curl -sL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/bin/yq && \
    chmod +x /usr/bin/yq

# Install cosign
RUN curl -sL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 -o /usr/local/bin/cosign && \
    chmod +x /usr/local/bin/cosign

# Install ec
RUN curl -sL https://github.com/enterprise-contract/ec-cli/releases/download/snapshot/ec_linux_amd64 -o /usr/local/bin/ec && \
    chmod +x /usr/local/bin/ec

# Update the package list and install necessary packages
USER root

# Update package manager and install required packages
RUN yum -y update && \
    #    yum -y install epel-release && \
    yum -y install python3.11 python3.11-devel gcc openssl-devel bzip2-devel libffi-devel make && \
    #    yum -y groupinstall "Development Tools" && \
    yum -y clean all

# Update alternatives to use Python 3.11
RUN update-alternatives --remove-all python
RUN alternatives --install /usr/bin/python python /usr/bin/python3.11 1
RUN update-alternatives --remove-all python3
RUN alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

# Switch back to the jenkins user
USER 1001