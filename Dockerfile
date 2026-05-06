FROM node:22-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    APP_ROOT=/foundry/FVTT \
    DATA_ROOT=/foundry/Data \
    CONFIG_ROOT=/foundry/Config \
    LOG_ROOT=/foundry/Logs \
    BACKUP_ROOT=/foundry/Backups \
    FOUNDRY_VERSION=14.161 \
    FOUNDRY_KEEP_PRIOR=5

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl unzip jq tini bash coreutils findutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/foundry

COPY scripts/ /opt/foundry/scripts/
RUN chmod +x /opt/foundry/scripts/*.sh

EXPOSE 30000

ENTRYPOINT ["/usr/bin/tini","--","/opt/foundry/scripts/entrypoint.sh"]