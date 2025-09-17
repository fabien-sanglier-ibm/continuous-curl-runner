# define the base image to create this image from
######################################################################################################

ARG BASE_IMAGE=redhat/ubi9-minimal
ARG BUILDER_IMAGE=redhat/ubi9-minimal

FROM $BASE_IMAGE as base

# 2. Define the builder, where we'll execute Product Installation and patching
######################################################################################################

FROM --platform=$BUILDPLATFORM $BUILDER_IMAGE as builder

ARG TARGETOS
ARG TARGETARCH
ARG TINI_VERSION v0.19.0

RUN true \
    && microdnf install \
         wget \
    && microdnf clean all \
    && true

RUN wget -P /tmp -O tini --no-check-certificate --no-cookies --quiet https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${TARGETARCH} \
    && wget -P /tmp -O tini.sha256sum --no-check-certificate --no-cookies --quiet https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${TARGETARCH}.sha256sum \
    && cd /tmp \
    && echo "$(cat tini.sha256sum)" | sha256sum -c \
    && true

# Finalize the image
######################################################################################################

FROM base as final

LABEL org.opencontainers.image.authors="fabien.sanglier@softwareaggov.com" \
      org.opencontainers.image.vendor="SoftwareAG Government Solutions" \
      org.opencontainers.image.title="continuous-curl-runner" \
      org.opencontainers.image.description="A simple runner to execute curl requests from a list of possible requests" \
      org.opencontainers.image.version="" \
      org.opencontainers.image.source="" \
      org.opencontainers.image.url="" \
      org.opencontainers.image.documentation=""

ENV REQUESTS_JSON_FILE=""
ENV REQUESTS_JSON=""
ENV REQUESTS_INTERVAL=""
ENV REQUESTS_SELECTION="random"
ENV CURL_OPTS=""

RUN true \
    && microdnf install \
         jq \
         gettext \
         bc \
    && microdnf clean all \
    && true

COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/curl_requests.sh /curl_requests.sh

COPY --from=builder /tmp/tini /tini
RUN chmod +x /tini

WORKDIR /

RUN chmod a+x entrypoint.sh curl_requests.sh

ENTRYPOINT ["/tini", "--", "/entrypoint.sh"]