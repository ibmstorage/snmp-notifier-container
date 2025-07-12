# Build stage 1

#FROM openshift/golang-builder:rhel_9_golang_1.23 AS builder
FROM quay.io/projectquay/golang:1.24 AS builder

COPY snmp_notifier snmp_notifier

WORKDIR snmp_notifier

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
FROM registry.redhat.io/ubi9/ubi-minimal

# Update the image to get the latest CVE updates
RUN microdnf update -y && \
    microdnf clean all

ENV OPBIN=/usr/local/bin/snmp_notifier

COPY --from=builder /go/snmp_notifier/snmp_notifier "$OPBIN"
COPY --from=builder /go/snmp_notifier/description-template.tpl /etc/snmp_notifier/description-template.tpl

LABEL maintainer="Guillaume Abrioux <gabrioux@redhat.com>"
LABEL com.redhat.component="snmp-notifier-container"
LABEL name="snmp-notifier"
LABEL version="1.2.1"
LABEL description="SNMP Notifier container"
LABEL summary="Provides snmp_notifier container."
LABEL io.k8s.display-name="SNMP Notifier container"
LABEL io.k8s.description="SNMP Notifier container receives alerts from the Prometheus' Alertmanager and routes them as SNMP traps."

RUN chmod +x "$OPBIN"

EXPOSE 9464
ENTRYPOINT ["/usr/local/bin/snmp_notifier"]
CMD ["--snmp.trap-description-template=/etc/snmp_notifier/description-template.tpl"]

