#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?version required}"

: "${FOUNDRY_EMAIL:=}"
: "${FOUNDRY_PASSWORD:=}"
: "${FOUNDRY_LICENSE_KEY:=}"
: "${FOUNDRY_ZIP_URL:=}"

if [ -n "${FOUNDRY_ZIP_URL:-}" ]; then
  printf '%s\n' "$FOUNDRY_ZIP_URL"
  exit 0
fi

if [ -z "$FOUNDRY_EMAIL" ] || [ -z "$FOUNDRY_PASSWORD" ]; then
  echo "Error: FOUNDRY_EMAIL and FOUNDRY_PASSWORD are required to download Foundry VTT" >&2
  echo "Alternatively, provide FOUNDRY_ZIP_URL with a timed download link" >&2
  exit 1
fi

cookie_jar="$(mktemp)"
trap 'rm -f "$cookie_jar"' EXIT

echo "Logging in to foundryvtt.com..." >&2

# Get initial cookies
curl -fsSL -c "$cookie_jar" -b "$cookie_jar" https://foundryvtt.com/ >/dev/null

# Login
curl -fsSL -c "$cookie_jar" -b "$cookie_jar" \
  -d "email=${FOUNDRY_EMAIL}" \
  -d "password=${FOUNDRY_PASSWORD}" \
  https://foundryvtt.com/auth/login >/dev/null

# Get download URL
echo "Fetching download URL for version ${VERSION}..." >&2
json="$(curl -fsSL -b "$cookie_jar" \
  "https://foundryvtt.com/api/releases/download?version=${VERSION}&platform=linux")"

url="$(printf '%s' "$json" | jq -r '.url // .download // empty')"

if [ -z "$url" ]; then
  echo "Error: Could not retrieve download URL for version ${VERSION}" >&2
  echo "API Response: $json" >&2
  exit 1
fi

printf '%s\n' "$url"