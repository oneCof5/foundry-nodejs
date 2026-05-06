#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?version required}"

: "${APP_ROOT:=/foundry/FVTT}"
: "${DATA_ROOT:=/foundry/Data}"
: "${CONFIG_ROOT:=/foundry/Config}"
: "${LOG_ROOT:=/foundry/Logs}"
: "${FOUNDRY_PORT:=30000}"
: "${FOUNDRY_WORLD_ID:=}"
: "${FOUNDRY_ADMIN_PASSWORD:=}"

APP_DIR="${APP_ROOT}/foundryvtt-${VERSION}"

mkdir -p "$DATA_ROOT/Config" "$LOG_ROOT"

if [ -n "$FOUNDRY_ADMIN_PASSWORD" ] && [ ! -f "$DATA_ROOT/Config/admin.txt" ]; then
  printf '%s' "$FOUNDRY_ADMIN_PASSWORD" > "$DATA_ROOT/Config/admin.txt"
fi

exec node "$APP_DIR/main.js" \
  --dataPath="$DATA_ROOT" \
  --port="$FOUNDRY_PORT" \
  ${FOUNDRY_WORLD_ID:+--world="$FOUNDRY_WORLD_ID"} \
  ${FOUNDRY_ADMIN_PASSWORD:+--adminPassword="$FOUNDRY_ADMIN_PASSWORD"} \
  >>"$LOG_ROOT/foundry.log" 2>&1