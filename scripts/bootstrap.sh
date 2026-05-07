#!/usr/bin/env bash
set -euo pipefail

# Verify running as user foundry:foundry
echo "Running as user: $(whoami) (UID:$(id -u), GID:$(id -g))"

: "${FOUNDRY_VERSION:=14.161}"
: "${FOUNDRY_KEEP_PRIOR:=5}"
: "${FOUNDRY_PORT:=30000}"
: "${FOUNDRY_WORLD_ID:=}"
: "${FOUNDRY_LICENSE_KEY_FILE:=/run/secrets/foundry_license_key}"
: "${FOUNDRY_EMAIL_FILE:=/run/secrets/foundry_email}"
: "${FOUNDRY_PASSWORD_FILE:=/run/secrets/foundry_password}"
: "${FOUNDRY_ADMIN_PASSWORD_FILE:=/run/secrets/foundry_admin_password}"
: "${FOUNDRY_ZIP_URL:=}"

read_secret() {
  local f="$1"
  local env_var="${2:-}"
  if [ -f "$f" ]; then 
    cat "$f"
  elif [ -n "$env_var" ]; then
    printf '%s' "$env_var"
  else
    printf ''
  fi
}

export FOUNDRY_LICENSE_KEY="$(read_secret "$FOUNDRY_LICENSE_KEY_FILE" "${FOUNDRY_LICENSE_KEY:-}")"
export FOUNDRY_EMAIL="$(read_secret "$FOUNDRY_EMAIL_FILE" "${FOUNDRY_EMAIL:-}")"
export FOUNDRY_PASSWORD="$(read_secret "$FOUNDRY_PASSWORD_FILE" "${FOUNDRY_PASSWORD:-}")"
export FOUNDRY_ADMIN_PASSWORD="$(read_secret "$FOUNDRY_ADMIN_PASSWORD_FILE" "${FOUNDRY_ADMIN_PASSWORD:-}")"

echo "Checking Foundry VTT installation..."

# Check if the requested version is already installed
INSTALLED_VERSION_FILE="/foundryvtt/.version"
if [ -f "$INSTALLED_VERSION_FILE" ]; then
  INSTALLED_VERSION="$(cat "$INSTALLED_VERSION_FILE")"
else
  INSTALLED_VERSION=""
fi

if [ "$INSTALLED_VERSION" = "$FOUNDRY_VERSION" ] && [ -f "/foundryvtt/main.js" ]; then
  echo "Foundry VTT ${FOUNDRY_VERSION} is already installed."
else
  echo "Installing Foundry VTT ${FOUNDRY_VERSION}..."
  /opt/foundry/scripts/install-foundry.sh "$FOUNDRY_VERSION"
  echo "$FOUNDRY_VERSION" > "$INSTALLED_VERSION_FILE"
fi

exec /opt/foundry/scripts/run-foundry.sh "$FOUNDRY_VERSION"