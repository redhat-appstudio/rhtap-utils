FROM registry.redhat.io/openshift4/ose-jenkins-agent-base
#FROM registry.redhat.io/ocp-tools-4/jenkins-agent-base-rhel8:v4.15.0-1721129898

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

# Install syft (Software Bill of Materials generator) TODO: change to rh-syft
RUN curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Install cosign
RUN curl -sL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 -o /usr/local/bin/cosign && \
    chmod +x /usr/local/bin/cosign
USER 1001