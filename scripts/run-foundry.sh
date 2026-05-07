#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?version required}"

: "${FOUNDRY_PORT:=30000}"
: "${FOUNDRY_WORLD_ID:=}"
: "${FOUNDRY_ADMIN_PASSWORD:=}"
: "${FOUNDRY_LICENSE_KEY:=}"

FVTT_APP_DIR="/foundryvtt"
FVTT_DATA_DIR="/data"
CONFIG_DIR="$FVTT_DATA_DIR/Config"
LOGS_DIR="$FVTT_DATA_DIR/Logs"

if [ ! -f "$FVTT_APP_DIR/main.js" ]; then
  echo "Error: Foundry VTT installation not found at ${FVTT_APP_DIR}" >&2
  exit 1
fi

mkdir -p "$CONFIG_DIR" "$LOGS_DIR"

# Set admin password if provided
if [ -n "$FOUNDRY_ADMIN_PASSWORD" ]; then
  if [ ! -f "$CONFIG_DIR/admin.txt" ]; then
    echo "Setting administrator password..."
    printf '%s' "$FOUNDRY_ADMIN_PASSWORD" > "$CONFIG_DIR/admin.txt"
  fi
else
  echo "WARNING: No admin password provided" >&2
  echo "Set FOUNDRY_ADMIN_PASSWORD environment variable or mount /run/secrets/foundry_admin_password" >&2
fi

# Validate admin password exists
if [ ! -f "$CONFIG_DIR/admin.txt" ] || [ ! -s "$CONFIG_DIR/admin.txt" ]; then
  echo "ERROR: Admin password is required but not configured" >&2
  echo "Please provide FOUNDRY_ADMIN_PASSWORD environment variable or secret" >&2
  exit 1
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

# Check for EULA acceptance
OPTIONS_FILE="$CONFIG_DIR/options.json"
if [ ! -f "$OPTIONS_FILE" ]; then
  echo "───────────────────────────────────────"
  echo "NOTICE: First-time setup required"
  echo "───────────────────────────────────────"
  echo "1. Access Foundry at http://your-server:${FOUNDRY_PORT}"
  echo "2. Accept the EULA"
  echo "3. Enter your license key (if not auto-configured)"
  echo "4. Complete initial setup"
  echo "───────────────────────────────────────"
fi

echo "───────────────────────────────────────"
echo "Starting Foundry VTT ${VERSION}..."
echo "Port: ${FOUNDRY_PORT}"
echo "Data Path: ${FVTT_DATA_DIR}"
echo "Admin Password: Configured ✓"
if [ -n "$FOUNDRY_LICENSE_KEY" ]; then
  echo "License Key: Configured ✓"
fi
if [ -n "$FOUNDRY_WORLD_ID" ]; then
  echo "World: ${FOUNDRY_WORLD_ID}"
fi
echo "───────────────────────────────────────"
echo "Access Foundry at http://your-server:${FOUNDRY_PORT}"
echo "───────────────────────────────────────"

# Change to foundryvtt directory and start
cd "$FVTT_APP_DIR"

# Start running the server (FoundryVTT V13 and newer)
exec node main.js \
  --dataPath="$FVTT_DATA_DIR" \
  --port="$FOUNDRY_PORT" \
  ${FOUNDRY_WORLD_ID:+--world="$FOUNDRY_WORLD_ID"}