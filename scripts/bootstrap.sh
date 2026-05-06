#!/usr/bin/env bash
set -euo pipefail

: "${APP_ROOT:=/foundry/FVTT}"
: "${DATA_ROOT:=/foundry/Data}"
: "${CONFIG_ROOT:=/foundry/Config}"
: "${LOG_ROOT:=/foundry/Logs}"
: "${FOUNDRY_VERSION:=14.161}"
: "${FOUNDRY_KEEP_PRIOR:=5}"
: "${FOUNDRY_PORT:=30000}"
: "${FOUNDRY_WORLD_ID:=}"
: "${FOUNDRY_LICENSE_KEY_FILE:=/run/secrets/foundry_license_key}"
: "${FOUNDRY_EMAIL_FILE:=/run/secrets/foundry_email}"
: "${FOUNDRY_PASSWORD_FILE:=/run/secrets/foundry_password}"
: "${FOUNDRY_ADMIN_PASSWORD_FILE:=/run/secrets/foundry_admin_password}"
: "${FOUNDRY_ZIP_DIR:=/foundry/FVTT}"
: "${FOUNDRY_ZIP_URL:=}"
: "${FOUNDRY_LOGIN_COOKIE:=}"

read_secret() {
  local f="$1"
  if [ -f "$f" ]; then cat "$f"; else printf '%s' "${2:-}"; fi
}

FOUNDRY_LICENSE_KEY="$(read_secret "$FOUNDRY_LICENSE_KEY_FILE" "${FOUNDRY_LICENSE_KEY:-}")"
FOUNDRY_EMAIL="$(read_secret "$FOUNDRY_EMAIL_FILE" "${FOUNDRY_EMAIL:-}")"
FOUNDRY_PASSWORD="$(read_secret "$FOUNDRY_PASSWORD_FILE" "${FOUNDRY_PASSWORD:-}")"
FOUNDRY_ADMIN_PASSWORD="$(read_secret "$FOUNDRY_ADMIN_PASSWORD_FILE" "${FOUNDRY_ADMIN_PASSWORD:-}")"

mkdir -p "$APP_ROOT" "$DATA_ROOT" "$CONFIG_ROOT" "$LOG_ROOT"

exec /opt/foundry/scripts/manage-version.sh