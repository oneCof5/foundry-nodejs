#!/usr/bin/env bash
set -euo pipefail

COLOR_RESET='\033[0m'
COLOR_DEBUG='\033[0;36m'
COLOR_DEFAULT='\033[0;37m'
SCRIPT_NAME="${0##*/}"
SCRIPT_NAME="${SCRIPT_NAME%.sh}"

: "${FOUNDRY_VERSION:=14.161}"
: "${FOUNDRY_ADMIN_PASSWORD_FILE:=/run/secrets/foundry_admin_password}"
: "${FOUNDRY_LICENSE_KEY_FILE:=/run/secrets/foundry_license_key}"
: "${FOUNDRY_ADMIN_PASSWORD:=}"
: "${FOUNDRY_LICENSE_KEY:=}"
: "${VERBOSE_LOGGING:=false}"

log_info() {
  echo -e "${COLOR_DEFAULT}${SCRIPT_NAME}: $*${COLOR_RESET}" >&2
}

log_debug() {
  if [ "$VERBOSE_LOGGING" = "true" ]; then
    echo -e "${COLOR_DEBUG}${SCRIPT_NAME}: $*${COLOR_RESET}" >&2
  fi
}

read_secret() {
  local file="$1"
  local fallback="${2:-}"
  if [ -f "$file" ]; then
    cat "$file"
  else
    printf '%s' "$fallback"
  fi
}

export FOUNDRY_ADMIN_PASSWORD="$(read_secret "$FOUNDRY_ADMIN_PASSWORD_FILE" "$FOUNDRY_ADMIN_PASSWORD")"
export FOUNDRY_LICENSE_KEY="$(read_secret "$FOUNDRY_LICENSE_KEY_FILE" "$FOUNDRY_LICENSE_KEY")"

INSTALLED_VERSION_FILE="/foundryvtt/.version"
INSTALLED_VERSION=""
if [ -f "$INSTALLED_VERSION_FILE" ]; then
  INSTALLED_VERSION="$(cat "$INSTALLED_VERSION_FILE")"
fi

if [ "$INSTALLED_VERSION" = "$FOUNDRY_VERSION" ] && { [ -f "/foundryvtt/main.js" ] || [ -f "/foundryvtt/resources/app/main.mjs" ]; }; then
  log_info "Foundry VTT ${FOUNDRY_VERSION} is already installed"
else
  log_info "Installing Foundry VTT ${FOUNDRY_VERSION}"
  /opt/foundry/scripts/install-foundry.sh "$FOUNDRY_VERSION"
fi

exec /opt/foundry/scripts/run-foundry.sh "$FOUNDRY_VERSION"