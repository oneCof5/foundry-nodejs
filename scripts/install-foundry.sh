#!/usr/bin/env bash
set -euo pipefail

COLOR_RESET='\033[0m'
COLOR_DEBUG='\033[0;36m'
COLOR_DEFAULT='\033[0;37m'
SCRIPT_NAME="${0##*/}"
SCRIPT_NAME="${SCRIPT_NAME%.sh}"
VERSION="${1:?version required}"

: "${FOUNDRY_RELEASE_URL:=}"
: "${VERBOSE_LOGGING:=false}"

log_info() {
  echo -e "${COLOR_DEFAULT}${SCRIPT_NAME}: $*${COLOR_RESET}" >&2
}

log_debug() {
  if [ "$VERBOSE_LOGGING" = "true" ]; then
    echo -e "${COLOR_DEBUG}${SCRIPT_NAME}: $*${COLOR_RESET}" >&2
  fi
}

FVTT_APP_DIR="/foundryvtt"
FVTT_CACHE_DIR="/data/FVTT"
PRIMARY_ZIP="${FVTT_CACHE_DIR}/FoundryVTT-Node-${VERSION}.zip"

mkdir -p "$FVTT_CACHE_DIR"

find_cached_zip() {
  local version="$1"
  local cache_dir="$2"
  local candidates=(
    "${cache_dir}/FoundryVTT-Node-${version}.zip"
    "${cache_dir}/Foundry-Node-${version}.zip"
  )
  local candidate
  for candidate in "${candidates[@]}"; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

FOUNDRY_ZIP=""
if FOUNDRY_ZIP="$(find_cached_zip "$VERSION" "$FVTT_CACHE_DIR")"; then
  log_info "Using cached Foundry archive: $(basename "$FOUNDRY_ZIP")"
else
  log_info "No cached archive found for Foundry Node ${VERSION}"
  if [ -z "$FOUNDRY_RELEASE_URL" ]; then
    log_info "Error: provide FOUNDRY_RELEASE_URL or pre-seed /data/FVTT with one of:" >&2
    log_info "  - FoundryVTT-Node-${VERSION}.zip" >&2
    log_info "  - Foundry-Node-${VERSION}.zip" >&2
    exit 1
  fi
  FOUNDRY_ZIP="$PRIMARY_ZIP"
  log_info "Downloading Foundry from timed URL"
  wget -q --show-progress -O "$FOUNDRY_ZIP" "$FOUNDRY_RELEASE_URL"
fi

ZIP_BASENAME="$(basename "$FOUNDRY_ZIP")"
case "$ZIP_BASENAME" in
  FoundryVTT-Node-"${VERSION}".zip|Foundry-Node-"${VERSION}".zip)
    ;;
  *)
    log_info "Error: invalid archive name '$ZIP_BASENAME'" >&2
    log_info "Expected FoundryVTT-Node-${VERSION}.zip or Foundry-Node-${VERSION}.zip" >&2
    exit 1
    ;;
esac

ZIP_SIZE=$(stat -c%s "$FOUNDRY_ZIP" 2>/dev/null || stat -f%z "$FOUNDRY_ZIP" 2>/dev/null || echo 0)
if [ "$ZIP_SIZE" -lt 1000000 ]; then
  log_info "Error: archive is too small (${ZIP_SIZE} bytes)" >&2
  exit 1
fi

log_info "Installing Foundry VTT ${VERSION} into ${FVTT_APP_DIR}"
mkdir -p "$FVTT_APP_DIR"
find "$FVTT_APP_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

unzip -q "$FOUNDRY_ZIP" -d "$FVTT_APP_DIR"

if [ ! -f "$FVTT_APP_DIR/main.js" ] && [ ! -f "$FVTT_APP_DIR/resources/app/main.mjs" ]; then
  log_info "Error: installation failed; no Foundry entrypoint found" >&2
  exit 1
fi

echo "$VERSION" > "${FVTT_APP_DIR}/.version"
log_info "Foundry VTT ${VERSION} installed successfully"
/opt/foundry/scripts/prune-cache.sh