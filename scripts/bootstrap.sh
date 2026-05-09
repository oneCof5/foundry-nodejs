#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/logging.sh"

: "${FVTT_VERSION}"
: "${FVTT_ADMIN_PASSWORD_FILE:=/run/secrets/foundry_admin_password}"
: "${FVTT_LICENSE_KEY_FILE:=/run/secrets/foundry_license_key}"
: "${FVTT_ADMIN_PASSWORD}"
: "${FVTT_LICENSE_KEY}"
: "${FVTT_VERBOSE_LOGGING}"
: "${FVTT_LOG_BASE}"

read_secret() {
  local file="$1"
  local fallback="${2:-}"
  if [ -f "$file" ]; then
    cat "$file"
  else
    printf '%s' "$fallback"
  fi
}

export FVTT_ADMIN_PASSWORD="$(read_secret "$FVTT_ADMIN_PASSWORD_FILE" "$FVTT_ADMIN_PASSWORD")"
export FVTT_LICENSE_KEY="$(read_secret "$FVTT_LICENSE_KEY_FILE" "$FVTT_LICENSE_KEY")"

INSTALLED_VERSION_FILE="/foundryvtt/.version"
INSTALLED_VERSION=""
if [ -f "$INSTALLED_VERSION_FILE" ]; then
  INSTALLED_VERSION="$(cat "$INSTALLED_VERSION_FILE")"
fi

if [ "$INSTALLED_VERSION" = "$FVTT_VERSION" ] && { [ -f "/foundryvtt/main.js" ] || [ -f "/foundryvtt/resources/app/main.mjs" ]; }; then
  log_info "Foundry VTT ${FVTT_VERSION} is already installed"
else
  log_info "Installing Foundry VTT ${FVTT_VERSION}"
  /opt/foundry/scripts/install-foundry.sh "$FVTT_VERSION"
fi

exec /opt/foundry/scripts/run-foundry.sh "$FVTT_VERSION"