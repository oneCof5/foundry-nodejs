# syntax=docker/dockerfile:1

ARG NODE_IMAGE_VERSION=24-bookworm-slim
ARG FOUNDRY_VERSION=14.161
ARG CONTAINER_VERSION=local

FROM node:${NODE_IMAGE_VERSION}

ARG FOUNDRY_VERSION
ARG CONTAINER_VERSION

ENV DEBIAN_FRONTEND=noninteractive \
    FOUNDRY_VERSION=${FOUNDRY_VERSION} \
    FOUNDRY_KEEP_PRIOR=5 \
    FOUNDRY_PORT=30000 \
    FOUNDRY_HOSTNAME= \
    FOUNDRY_ROUTE_PREFIX= \
    FOUNDRY_PROXY_SSL=false \
    FOUNDRY_PROXY_PORT=443 \
    FOUNDRY_MINIFY_STATIC_FILES=true \
    FOUNDRY_UPNP=false \
    FOUNDRY_COMPRESS_SOCKET=false \
    FOUNDRY_COMPRESS_WEBSOCKET=false \
    FOUNDRY_LANGUAGE=en.core \
    FOUNDRY_WORLD= \
    FOUNDRY_ADMIN_PASSWORD= \
    FOUNDRY_LICENSE_KEY= \
    FOUNDRY_RELEASE_URL= \
    PUID=911 \
    PGID=911 \
    HOME=/home/foundry

LABEL com.foundryvtt.version="${FOUNDRY_VERSION}" \
      org.opencontainers.image.title="foundry-nodejs" \
      org.opencontainers.image.version="${CONTAINER_VERSION}" \
      org.opencontainers.image.vendor="oneCof5" \
      org.opencontainers.image.description="Foundry VTT Node container with runtime installer using cached or timed release URLs"

WORKDIR /opt/foundry

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      findutils \
      gosu \
      jq \
      tini \
      tzdata \
      unzip \
      wget \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && apt-get clean

RUN groupadd -g 911 foundry \
    && useradd -u 911 -g foundry -m -d /home/foundry -s /bin/bash foundry \
    && mkdir -p /opt/foundry/scripts /foundryvtt /data /logs \
    && chown -R foundry:foundry /home/foundry /foundryvtt /data /logs

COPY --chmod=755 scripts/*.sh /opt/foundry/scripts/

EXPOSE 30000/tcp
VOLUME ["/data", "/logs", "/foundryvtt"]

HEALTHCHECK --start-period=3m --interval=30s --timeout=5s \
  CMD ["/opt/foundry/scripts/healthcheck.sh"]

ENTRYPOINT ["/usr/bin/tini","--","/opt/foundry/scripts/entrypoint.sh"]