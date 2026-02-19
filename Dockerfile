# Build stage 1
FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder:rhel_9_golang_1.24 AS builder

COPY snmp_notifier snmp_notifier

WORKDIR snmp_notifier

#RUN dnf remove -y glibc-langpack-en && dnf install -y glibc glibc-devel glibc-static

RUN dnf install -y glibc-static

# Build the binary
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -mod=readonly \
    -o snmp_notifier \
    -ldflags "-s \
      -X github.com/prometheus/common/version.Version=1.2.1 \
      -X github.com/prometheus/common/version.Revision=14ba67401c61cfc2f19ebd9ace8acdcf47b4cd49 \
      -X github.com/prometheus/common/version.Branch=master \
      -X github.com/prometheus/common/version.BuildUser=osbs \
      -X github.com/prometheus/common/version.BuildDate=20211104-18:55:37 \
      -extldflags '-static'" \
    -a -tags netgo

# Build stage 2
FROM registry.redhat.io/ubi10-minimal:latest

# Update the image to get the latest CVE updates
RUN microdnf update -y && \
    microdnf clean all

ENV OPBIN=/usr/local/bin/snmp_notifier

COPY --from=builder /snmp_notifier/snmp_notifier "$OPBIN"
COPY --from=builder /snmp_notifier/description-template.tpl /etc/snmp_notifier/description-template.tpl

LABEL maintainer="Guillaume Abrioux <gabrioux@redhat.com>"
LABEL com.redhat.component="snmp-notifier-container"
LABEL name=rhceph/snmp-notifier-rhel10
LABEL version="1.2.1"
LABEL description="SNMP Notifier container"
LABEL summary="Provides snmp_notifier container."
LABEL io.k8s.display-name="SNMP Notifier container"
LABEL io.k8s.description="SNMP Notifier container receives alerts from the Prometheus' Alertmanager and routes them as SNMP traps."
LABEL io.openshift.tags="1.2.1"
LABEL cpe=cpe:/a:redhat:ceph_storage:9.1::el9


RUN chmod +x "$OPBIN"

RUN mkdir /licenses
COPY ./licenses /licenses

EXPOSE 9464
ENTRYPOINT ["/usr/local/bin/snmp_notifier"]
CMD ["--snmp.trap-description-template=/etc/snmp_notifier/description-template.tpl"]
