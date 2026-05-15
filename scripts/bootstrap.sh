#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/logging.sh"

: "${FVTT_APP_DIR}"
: "${FVTT_DATA_DIR}"
: "${FVTT_LOGS_DIR}"
: "${FVTT_VERSION}"
: "${FVTT_ADMIN_PASSWORD}"
: "${FVTT_LICENSE_KEY}"
: "${FVTT_VERBOSE_LOGGING}"

read_secret_required() {
  local file_path="$1"
  local label="$2"

  if [ ! -s "$file_path" ]; then
    log_error "${label} secret file is missing or empty at ${file_path}"
    exit 1
  fi

  tr -d '\r' < "$file_path"
}

log_info "Reading secrets from /run/secrets..."
if [ -f /run/secrets/foundry_admin_password ]; then
  export FVTT_ADMIN_PASSWORD="$(
    read_secret_required "/run/secrets/foundry_admin_password" "Admin password"
  )"
fi

if [ -f /run/secrets/foundry_password_salt ]; then
  export FVTT_PASSWORD_SALT="$(
    read_secret_required "/run/secrets/foundry_password_salt" "Password Salt"
  )"
fi

if [ -f /run/secrets/foundry_license_key ]; then
  export FVTT_LICENSE_KEY="$(
    read_secret_required "/run/secrets/foundry_license_key" "License key"
  )"
fi

if [ -f /run/secrets/foundry_release_url ]; then
  export FVTT_RELEASE_URL="$(
    read_secret_required "/run/secrets/foundry_release_url" "Release URL"
  )"
fi
log_info "Secrets loaded successfully"

INSTALLED_VERSION_FILE="${FVTT_DATA_DIR}/.version"
INSTALLED_VERSION=""

if [ -f "$INSTALLED_VERSION_FILE" ]; then
  log_debug "Found existing version file at $INSTALLED_VERSION_FILE"
  INSTALLED_VERSION="$(tr -d '\r\n' < "$INSTALLED_VERSION_FILE")"
  log_debug "Read installed version '$INSTALLED_VERSION' from $INSTALLED_VERSION_FILE"
else
  log_warn "Existing version not found; installing new instance by default"
fi

APP_MAIN_JS="${FVTT_APP_DIR}/main.js"
APP_MAIN_MJS="${FVTT_APP_DIR}/resources/app/main.mjs"

log_debug "Requested version: '$FVTT_VERSION'"
log_debug "Installed version: '$INSTALLED_VERSION'"
log_debug "main.js exists: $( [ -f "$APP_MAIN_JS" ] && echo true || echo false )"
log_debug "main.mjs exists: $( [ -f "$APP_MAIN_MJS" ] && echo true || echo false )"

if [ "$INSTALLED_VERSION" = "$FVTT_VERSION" ] && { [ -f "$APP_MAIN_JS" ] || [ -f "$APP_MAIN_MJS" ]; }; then
  log_info "Foundry VTT ${FVTT_VERSION} is already installed"
else
  log_info "Installing Foundry VTT ${FVTT_VERSION}"
  /opt/foundry/scripts/install-foundry.sh "$FVTT_VERSION"
fi

exec /opt/foundry/scripts/run-foundry.sh "$FVTT_VERSION"