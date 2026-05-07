#!/usr/bin/env bash
set -euo pipefail

: "${FOUNDRY_PORT:=30000}"

CONFIG_DIR="/data/Config"
ADMIN_PASSWORD_FILE="$CONFIG_DIR/admin.txt"
OPTIONS_FILE="$CONFIG_DIR/options.json"

# Check 1: Admin password must exist
if [ ! -f "$ADMIN_PASSWORD_FILE" ]; then
  echo "Healthcheck FAIL: Admin password file not found at $ADMIN_PASSWORD_FILE" >&2
  exit 1
fi

# Check 2: Admin password must not be empty
if [ ! -s "$ADMIN_PASSWORD_FILE" ]; then
  echo "Healthcheck FAIL: Admin password file is empty" >&2
  exit 1
fi

# Check 3: EULA acceptance (Foundry creates options.json after EULA acceptance)
if [ ! -f "$OPTIONS_FILE" ]; then
  echo "Healthcheck WARN: EULA not yet accepted (options.json not found)" >&2
  # Don't fail here - this is expected on first startup
  # Container is healthy but setup not complete
fi

# Check 4: Foundry web service is responding
if ! curl -f -s -o /dev/null "http://localhost:${FOUNDRY_PORT}" 2>/dev/null; then
  echo "Healthcheck FAIL: Foundry not responding on port ${FOUNDRY_PORT}" >&2
  exit 1
fi

# Check 5: Foundry app is installed
if [ ! -f "/foundryvtt/main.js" ]; then
  echo "Healthcheck FAIL: Foundry application not installed" >&2
  exit 1
fi

echo "Healthcheck PASS: Foundry is healthy"
exit 0