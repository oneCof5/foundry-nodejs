FROM node:24-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/home/foundry \
    FOUNDRY_VERSION=14.161 \
    FOUNDRY_KEEP_PRIOR=5 \
    PUID=911 \
    PGID=911

# Install dependencies in a single layer and clean up
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      wget \
      unzip \
      jq \
      tini \
      gosu \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* /var/tmp/* \
    && apt-get clean

# Create foundry user, group, and directories in single layer
RUN groupadd -g 911 foundry \
    && useradd -u 911 -g foundry -m -d /home/foundry -s /bin/bash foundry \
    && mkdir -p /home/foundry/foundryvtt /home/foundry/foundrydata \
    && chown -R foundry:foundry /home/foundry

WORKDIR /opt/foundry

# Copy scripts and set permissions in single layer
COPY scripts/ /opt/foundry/scripts/
RUN chmod +x /opt/foundry/scripts/*.sh \
    && chown -R foundry:foundry /opt/foundry/scripts

EXPOSE 30000

ENTRYPOINT ["/usr/bin/tini","--","/opt/foundry/scripts/entrypoint.sh"]