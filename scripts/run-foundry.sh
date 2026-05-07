#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?version required}"

: "${HOME:=/home/foundry}"
: "${FOUNDRY_PORT:=30000}"
: "${FOUNDRY_WORLD_ID:=}"
: "${FOUNDRY_ADMIN_PASSWORD:=}"
: "${FOUNDRY_LICENSE_KEY:=}"

FVTT_APP_DIR="$HOME/foundryvtt"
FVTT_DATA_DIR="$HOME/foundrydata"
CONFIG_DIR="$FVTT_DATA_DIR/Config"
LOGS_DIR="$FVTT_DATA_DIR/Logs"

if [ ! -f "$FVTT_APP_DIR/main.js" ]; then
  echo "Error: Foundry VTT installation not found at ${FVTT_APP_DIR}" >&2
  exit 1
fi

mkdir -p "$CONFIG_DIR" "$LOGS_DIR"

# Set admin password if provided
if [ -n "$FOUNDRY_ADMIN_PASSWORD" ] && [ ! -f "$CONFIG_DIR/admin.txt" ]; then
  echo "Setting administrator password..."
  printf '%s' "$FOUNDRY_ADMIN_PASSWORD" > "$CONFIG_DIR/admin.txt"
fi

# Set license key if provided
if [ -n "$FOUNDRY_LICENSE_KEY" ]; then
  echo "Configuring license key..."
  cat > "$CONFIG_DIR/license.json" <<EOF
{
  "license": "${FOUNDRY_LICENSE_KEY}"
}
EOF
fi

echo "───────────────────────────────────────"
echo "Starting Foundry VTT ${VERSION}..."
echo "Port: ${FOUNDRY_PORT}"
echo "Data Path: ${FVTT_DATA_DIR}"
if [ -n "$FOUNDRY_WORLD_ID" ]; then
  echo "World: ${FOUNDRY_WORLD_ID}"
fi
echo "───────────────────────────────────────"
echo "Access Foundry at http://your-server:${FOUNDRY_PORT}"
echo "───────────────────────────────────────"

# Change to foundryvtt directory and start (following official instructions)
cd "$FVTT_APP_DIR"

# Start running the server (FoundryVTT V13 and newer)
exec node main.js \
  --dataPath="$FVTT_DATA_DIR" \
  --port="$FOUNDRY_PORT" \
  ${FOUNDRY_WORLD_ID:+--world="$FOUNDRY_WORLD_ID"}