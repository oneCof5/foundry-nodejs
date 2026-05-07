FROM node:22-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    APP_ROOT=/foundry/FVTT \
    DATA_ROOT=/foundry/Data \
    CONFIG_ROOT=/foundry/Config \
    LOG_ROOT=/foundry/Logs \
    BACKUP_ROOT=/foundry/Backups \
    FOUNDRY_VERSION=14.161 \
    FOUNDRY_KEEP_PRIOR=5 \
    PUID=911 \
    PGID=911

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl unzip jq tini bash coreutils findutils gosu \
    && rm -rf /var/lib/apt/lists/*

# Create foundry user and group with default IDs
RUN groupadd -g 911 foundry && \
    useradd -u 911 -g foundry -d /foundry -s /bin/bash foundry

# Create directories with proper ownership
RUN mkdir -p /foundry/FVTT /foundry/Data /foundry/Config /foundry/Logs /foundry/Backups && \
    chown -R foundry:foundry /foundry

WORKDIR /opt/foundry

COPY scripts/ /opt/foundry/scripts/
RUN chmod +x /opt/foundry/scripts/*.sh

EXPOSE 30000

ENTRYPOINT ["/usr/bin/tini","--","/opt/foundry/scripts/entrypoint.sh"]
