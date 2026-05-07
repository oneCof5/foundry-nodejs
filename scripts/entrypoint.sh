#!/usr/bin/env bash
set -euo pipefail

: "${PUID:=911}"
: "${PGID:=911}"
: "${HOME:=/home/foundry}"
: "${FOUNDRY_VERSION:=14.161}"
: "${FOUNDRY_KEEP_PRIOR:=5}"
: "${FOUNDRY_PORT:=30000}"

echo "───────────────────────────────────────"
echo "Foundry VTT Docker Container"
echo "───────────────────────────────────────"
echo "User UID:    $PUID"
echo "User GID:    $PGID"
echo "Version:     $FOUNDRY_VERSION"
echo "Home:        $HOME"
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

# Ensure foundry directories exist (following official pattern)
mkdir -p \
  "$HOME/foundryvtt" \
  "$HOME/foundrydata/Config" \
  "$HOME/foundrydata/Data" \
  "$HOME/foundrydata/Logs" \
  "$HOME/foundrydata/Backups" \
  "$HOME/foundrydata/FVTT"

echo "Ensuring proper ownership of $HOME..."
chown -R foundry:foundry "$HOME"

# Drop to non-root user and continue
echo "Switching to foundry user (UID:$PUID, GID:$PGID)..."
exec gosu foundry /opt/foundry/scripts/bootstrap.sh