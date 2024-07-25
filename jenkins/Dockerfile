FROM registry.redhat.io/ocp-tools-4/jenkins-rhel8:v4.15.0-1721131535
USER root

# RUN subscription-manager config --rhsm.manage_repos=1
# RUN yum -y install tree
# Install tree from Fedora repository
# RUN yum install -y 'dnf-command(config-manager)' && \
#     dnf config-manager --add-repo https://download.fedoraproject.org/pub/fedora/linux/releases/38/Everything/x86_64/os/ && \
#     dnf install -y tree --nogpgcheck && \
#    # dnf config-manager --set-disabled fedora && \
#     rm -rf /var/cache/dnf

    # Download and install tree RPM package https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/tree-1.8.0-10.el9.x86_64.rpm
    
RUN curl -sL https://vault.centos.org/8.5.2111/BaseOS/x86_64/os/Packages/tree-1.7.0-15.el8.x86_64.rpm -o /tmp/tree.rpm && \
yum localinstall -y /tmp/tree.rpm && \
rm -f /tmp/tree.rpm


# install buildah TODO: some issue with UID, PID - buildah do not work yet
# Don't include container-selinux and remove
# directories used by yum that are just taking
# up space.
#RUN yum -y install buildah
# Command is from RH buildah image
RUN useradd build; dnf -y module enable container-tools:rhel8; dnf -y update; dnf -y reinstall shadow-utils; dnf -y install buildah fuse-overlayfs /etc/containers/storage.conf; rm -rf /var/cache/* /var/log/dnf* /var/log/yum.*

# Adjust storage.conf to enable Fuse storage.
RUN sed -i -e 's|^#mount_program|mount_program|g' -e '/additionalimage.*/a "/var/lib/shared",' /etc/containers/storage.conf
RUN mkdir -p /var/lib/shared/overlay-images /var/lib/shared/overlay-layers; touch /var/lib/shared/overlay-images/images.lock; touch /var/lib/shared/overlay-layers/layers.lock

# Set up environment variables to note that this is
# not starting with usernamespace and default to
# isolate the filesystem with chroot.
ENV _BUILDAH_STARTED_IN_USERNS="" BUILDAH_ISOLATION=chroot

# Clean up YUM cache
RUN yum clean all && rm -rf /var/cache/yum
# Set UID for buildah
RUN echo jenkins:10000:65536 >> /etc/subuid
RUN echo jenkins:10000:65536 >> /etc/subgid

# Install yq (YAML processor)
RUN curl -sL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/bin/yq && \
    chmod +x /usr/bin/yq

# Install syft (Software Bill of Materials generator) TODO: change to rh-syft
RUN curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Install cosign
RUN curl -sL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 -o /usr/local/bin/cosign && \
    chmod +x /usr/local/bin/cosign

# Switch back to the Jenkins user (maybe not necessary)
USER jenkins