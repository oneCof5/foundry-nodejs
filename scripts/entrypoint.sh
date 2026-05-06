#!/usr/bin/env bash
set -euo pipefail

: "${APP_ROOT:=/foundry/FVTT}"
: "${DATA_ROOT:=/foundry/Data}"
: "${CONFIG_ROOT:=/foundry/Config}"
: "${LOG_ROOT:=/foundry/Logs}"
: "${FOUNDRY_VERSION:=14.161}"
: "${FOUNDRY_KEEP_PRIOR:=5}"
: "${FOUNDRY_PORT:=30000}"

mkdir -p "$APP_ROOT" "$DATA_ROOT" "$CONFIG_ROOT" "$LOG_ROOT"

exec /opt/foundry/scripts/bootstrap.sh