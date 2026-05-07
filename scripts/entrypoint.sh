#!/usr/bin/env bash
set -euo pipefail

: "${PUID:=911}"
: "${PGID:=911}"
: "${FOUNDRY_VERSION:=14.161}"
: "${FOUNDRY_KEEP_PRIOR:=5}"
: "${FOUNDRY_PORT:=30000}"

echo "───────────────────────────────────────"
echo "Foundry VTT Docker Container"
echo "───────────────────────────────────────"
echo "User UID:    $PUID"
echo "User GID:    $PGID"
echo "Version:     $FOUNDRY_VERSION"
echo "───────────────────────────────────────"

# Update foundry user to match PUID/PGID
CURRENT_PGID=$(id -g foundry)
CURRENT_PUID=$(id -u foundry)

if [ "$CURRENT_PGID" != "$PGID" ]; then
    echo "Updating foundry group ID to $PGID..."
    groupmod -o -g "$PGID" foundry
fi

if [ "$CURRENT_PUID" != "$PUID" ]; then
    echo "Updating foundry user ID to $PUID..."
    usermod -o -u "$PUID" foundry
fi

# Ensure foundry directories exist
mkdir -p \
  "/foundryvtt" \
  "/data/Config" \
  "/data/Data" \
  "/data/Logs" \
  "/data/Backups" \
  "/data/FVTT"

# Ensure foundry:foundry owns the directories
echo "Ensuring proper ownership of directories..."
chown -R foundry:foundry /foundryvtt /data

# Drop to non-root user and continue
echo "Switching to foundry user (UID:$PUID, GID:$PGID)..."
exec gosu foundry /opt/foundry/scripts/bootstrap.sh