#!/usr/bin/env bash
set -euo pipefail

: "${APP_ROOT:=/foundry/FVTT}"
: "${FOUNDRY_VERSION:=14.161}"
: "${FOUNDRY_KEEP_PRIOR:=5}"
: "${FOUNDRY_ZIP_DIR:=/foundry/FVTT}"
: "${FOUNDRY_EMAIL:=}"
: "${FOUNDRY_PASSWORD:=}"
: "${FOUNDRY_LICENSE_KEY:=}"
: "${FOUNDRY_ZIP_URL:=}"

version_to_name() {
  local v="$1"
  echo "foundryvtt-${v}"
}

is_installed() {
  local v="$1"
  [ -f "${APP_ROOT}/$(version_to_name "$v")/main.js" ]
}

latest_local_version() {
  find "$APP_ROOT" -maxdepth 1 -type d -name 'foundryvtt-*' \
    | sed 's|.*/foundryvtt-||' \
    | sort -Vr \
    | head -n 1
}

ensure_version_zip() {
  local v="$1"
  local zip="${APP_ROOT}/foundryvtt-${v}.zip"
  if [ -f "$zip" ]; then return 0; fi
  if [ -n "$FOUNDRY_ZIP_URL" ]; then
    curl -fL "$FOUNDRY_ZIP_URL" -o "$zip"
    return 0
  fi
  /opt/foundry/scripts/fetch-download-url.sh "$v" > /tmp/foundry_download_url
  local url
  url="$(cat /tmp/foundry_download_url)"
  curl -fL "$url" -o "$zip"
}

install_version() {
  local v="$1"
  local zip="${APP_ROOT}/foundryvtt-${v}.zip"
  local dir="${APP_ROOT}/$(version_to_name "$v")"
  mkdir -p "$dir"
  unzip -o "$zip" -d "$dir" >/dev/null
}

if ! is_installed "$FOUNDRY_VERSION"; then
  ensure_version_zip "$FOUNDRY_VERSION"
  install_version "$FOUNDRY_VERSION"
fi

/opt/foundry/scripts/prune-old.sh

exec /opt/foundry/scripts/run-foundry.sh "$FOUNDRY_VERSION"