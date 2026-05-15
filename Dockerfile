# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv

ARG NODE_IMAGE_VERSION=24-bookworm-slim
ARG FVTT_VERSION=14.161
ARG CONT_VERSION=local

FROM node:${NODE_IMAGE_VERSION}

ARG FVTT_VERSION
ARG CONT_VERSION

ENV DEBIAN_FRONTEND=noninteractive \
    \
    # Foundry version & retention
    FVTT_VERSION=${FVTT_VERSION} \
    FVTT_KEEP_PRIOR_COPIES=5 \
    \
    # Options.json / server configuration inputs
    FVTT_AWS_CONFIG= \
    FVTT_COMPRESS_SOCKET=false \
    FVTT_COMPRESS_STATIC=false \
    FVTT_CSS_THEME=dark \  
    FVTT_DELETE_NEDB=false \  
    FVTT_FULLSCREEN=false \
    FVTT_HOSTNAME=fvtt.mydomain.com \
    FVTT_HOT_RELOAD=false \
    FVTT_LANGUAGE=en.core \
    FVTT_LOCAL_HOSTNAME=localhost \
    FVTT_NOUPDATE=true \
    FVTT_PASSWORD_SALT= \
    FVTT_PORT=30000 \
    FVTT_PROTOCOL=4 \
    FVTT_PROXY_PORT= \
    FVTT_PROXY_SSL=false \
    FVTT_ROUTE_PREFIX= \
    FVTT_SERVICE_CONFIG= \
    FVTT_SSL_CERT_PATH= \
    FVTT_SSL_KEY_PATH= \
    FVTT_TELEMETRY_ENABLED=false \
    FVTT_TEMP_DIR= \
    FVTT_UNIX_SOCKET= \
    FVTT_UPDATE_CHANNEL=stable \
    FVTT_UPNP_ENABLED=false \
    FVTT_UPNP_LEASE_DURATION= \
    FVTT_WORLD= \
    FVTT_ADMIN_PASSWORD= \
    FVTT_NO_BACKUPS=false \
    \
    # Install / licensing 
    FVTT_LICENSE_KEY= \
    FVTT_RELEASE_URL= \
    \
    # Logging \
    FVTT_VERBOSE_LOGGING=false \
    FVTT_LOG_MAX_SIZE_BYTES=104857600 \
    FVTT_LOG_KEEP_ROTATED=10 \
    FVTT_LOG_TO_STDERR=true  \
    FVTT_LOG_USE_COLOR=true  \
    \
    # Base Container Paths \
    FVTT_APP_DIR=/foundryvtt \
    FVTT_DATA_DIR=/data \
    FVTT_LOGS_DIR=/logs \
    \
    # Container runtime identity \
    PUID=911 \
    PGID=911
    
LABEL com.foundryvtt.version="${FVTT_VERSION}" \
      org.opencontainers.image.title="foundry-nodejs" \
      org.opencontainers.image.version="${CONT_VERSION}" \
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