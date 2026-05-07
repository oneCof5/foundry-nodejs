#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?version required}"

: "${HOME:=/home/foundry}"
: "${FOUNDRY_EMAIL:=}"
: "${FOUNDRY_PASSWORD:=}"
: "${FOUNDRY_ZIP_URL:=}"

FVTT_APP_DIR="$HOME/foundryvtt"
FVTT_CACHE_DIR="$HOME/foundrydata/FVTT"
ZIP_FILE="${FVTT_CACHE_DIR}/foundryvtt-${VERSION}.zip"

mkdir -p "$FVTT_CACHE_DIR"

# Check if zip already exists in cache
if [ ! -f "$ZIP_FILE" ]; then
  echo "Foundry VTT ${VERSION} zip not found in cache."
  
  if [ -n "$FOUNDRY_ZIP_URL" ]; then
    echo "Downloading from provided URL..."
    wget -q --show-progress -O "$ZIP_FILE" "$FOUNDRY_ZIP_URL"
  elif [ -n "$FOUNDRY_EMAIL" ] && [ -n "$FOUNDRY_PASSWORD" ]; then
    echo "Downloading from foundryvtt.com..."
    url="$(/opt/foundry/scripts/fetch-download-url.sh "$VERSION")"
    wget -q --show-progress -O "$ZIP_FILE" "$url"
  else
    echo "Error: Cannot download Foundry VTT ${VERSION}" >&2
    echo "Please provide one of:" >&2
    echo "  - FOUNDRY_ZIP_URL (timed download link)" >&2
    echo "  - FOUNDRY_EMAIL and FOUNDRY_PASSWORD (account credentials)" >&2
    echo "  - Pre-download zip to: ${ZIP_FILE}" >&2
    exit 1
  fi
else
  echo "Using cached Foundry VTT ${VERSION} zip."
fi

# Install the software
echo "Installing Foundry VTT ${VERSION} to ${FVTT_APP_DIR}..."
cd "$FVTT_APP_DIR"
rm -rf ./* 2>/dev/null || true
unzip -q "$ZIP_FILE"

# Verify installation
if [ ! -f "$FVTT_APP_DIR/main.js" ]; then
  echo "Error: Installation failed - main.js not found" >&2
  exit 1
fi

echo "Foundry VTT ${VERSION} installed successfully."

# Prune old zips from cache
/opt/foundry/scripts/prune-cache.sh