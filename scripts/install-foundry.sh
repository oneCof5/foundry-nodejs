#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/logging.sh"

VERSION="${1:?version required}"

: "${FVTT_RELEASE_URL_FILE:=/run/secrets/foundry_release_url}}"
: "${FVTT_RELEASE_URL}"
: "${FVTT_VERBOSE_LOGGING}"
: "${FVTT_LOG_BASE}"

ZIP_ARCHIVE_DIR="/data/InstallerCache"
INSTALLER_ZIP="${ZIP_ARCHIVE_DIR}/FoundryVTT-Node-${VERSION}.zip"

mkdir -p "$ZIP_ARCHIVE_DIR"

read_secret() {
  local file="$1"
  local fallback="${2:-}"
  if [ -f "$file" ]; then
    cat "$file"
  else
    printf '%s' "$fallback"
  fi
}

export FVTT_RELEASE_URL="$(read_secret "$FVTT_RELEASE_URL_FILE" "$FVTT_RELEASE_URL")"

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
if FOUNDRY_ZIP="$(find_cached_zip "$VERSION" "$ZIP_ARCHIVE_DIR")"; then
  log_info "Using cached Foundry archive: $(basename "$FOUNDRY_ZIP")"
else
  log_info "No cached archive found for Foundry Node ${VERSION}"

  if [ -z "$FVTT_RELEASE_URL" ]; then
    log_error "Provide one of the following install sources:"
    log_error "  - FVTT_RELEASE_URL"
    log_error "  - FVTT_RELEASE_URL_FILE"
    log_error "  - /run/secrets/foundry_release_url"
    log_error "  - Pre-seed /data/InstallerCache with one of:"
    log_error "      FoundryVTT-Node-${VERSION}.zip"
    log_error "      Foundry-Node-${VERSION}.zip"
    exit 1
  fi

  FOUNDRY_ZIP="$INSTALLER_ZIP"
  log_info "Downloading Foundry from timed URL"
  wget -q --show-progress -O "$FOUNDRY_ZIP" "$FVTT_RELEASE_URL"
fi

ZIP_BASENAME="$(basename "$FOUNDRY_ZIP")"
case "$ZIP_BASENAME" in
  FoundryVTT-Node-"${VERSION}".zip|Foundry-Node-"${VERSION}".zip)
    ;;
  *)
    log_error "Invalid archive name '$ZIP_BASENAME'"
    log_error "Expected FoundryVTT-Node-${VERSION}.zip or Foundry-Node-${VERSION}.zip"
    exit 1
    ;;
esac

ZIP_SIZE=$(stat -c%s "$FOUNDRY_ZIP" 2>/dev/null || stat -f%z "$FOUNDRY_ZIP" 2>/dev/null || echo 0)
if [ "$ZIP_SIZE" -lt 1000000 ]; then
  log_error "Archive is too small (${ZIP_SIZE} bytes)"
  exit 1
fi

log_info "Installing Foundry VTT ${VERSION} into ${FVTT_APP_DIR}"
find "$FVTT_APP_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

# setup progession based logging
mapfile -t entries < <(unzip -Z1 "$FOUNDRY_ZIP")
total=${#entries[@]}
log_debug "Extracting ${total} file(s) into ${FVTT_APP_DIR}..."

count=0
for name in "${entries[@]}"; do
  unzip -q "$FOUNDRY_ZIP" "$name" -d "$FVTT_APP_DIR"
  count=$((count + 1))
  if (( count % 500 == 0 || count == total )); then
    log_debug "Extraction progress: $count / $total files"
  fi
done

log_debug "Install command: unzip -q ${FOUNDRY_ZIP} -d ${FVTT_APP_DIR}"
unzip -oq "$FOUNDRY_ZIP" -d "$FVTT_APP_DIR"
log_debug "Unzip completed."

if [ ! -f "$FVTT_APP_DIR/main.js" ] && [ ! -f "$FVTT_APP_DIR/resources/app/main.mjs" ]; then
  log_error "Installation failed; no Foundry entrypoint found"
  exit 1
fi

echo "$VERSION" > "${FVTT_APP_DIR}/.version"
log_info "Foundry VTT ${VERSION} installed successfully"
/opt/foundry/scripts/prune-cache.sh