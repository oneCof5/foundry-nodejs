#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?version required}"

: "${FOUNDRY_EMAIL:=}"
: "${FOUNDRY_PASSWORD:=}"
: "${FOUNDRY_ZIP_URL:=}"

if [ -n "${FOUNDRY_ZIP_URL:-}" ]; then
  printf '%s\n' "$FOUNDRY_ZIP_URL"
  exit 0
fi

if [ -z "$FOUNDRY_EMAIL" ] || [ -z "$FOUNDRY_PASSWORD" ]; then
  echo "Error: FOUNDRY_EMAIL and FOUNDRY_PASSWORD are required" >&2
  exit 1
fi

echo "Logging in to foundryvtt.com..." >&2

cookie_jar="$(mktemp)"
trap 'rm -f "$cookie_jar"' EXIT

# Get initial cookies
if ! curl -fsSL -c "$cookie_jar" https://foundryvtt.com/ >/dev/null 2>&1; then
  echo "Error: Failed to connect to foundryvtt.com" >&2
  exit 1
fi

# Try API login first
echo "Attempting API login..." >&2
api_login_result=$(curl -fsSL -c "$cookie_jar" -b "$cookie_jar" \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${FOUNDRY_EMAIL}\",\"password\":\"${FOUNDRY_PASSWORD}\"}" \
  https://foundryvtt.com/api/auth/login 2>&1 || echo "FAILED")

if [[ "$api_login_result" == "FAILED" ]]; then
  echo "API login failed, trying form login..." >&2
  if ! curl -fsSL -c "$cookie_jar" -b "$cookie_jar" \
    -d "email=${FOUNDRY_EMAIL}" \
    -d "password=${FOUNDRY_PASSWORD}" \
    https://foundryvtt.com/auth/login >/dev/null 2>&1; then
    echo "Error: Login failed - check your credentials" >&2
    exit 1
  fi
fi

# Get download URL
echo "Fetching download link for version ${VERSION}..." >&2
json=$(curl -fsSL -b "$cookie_jar" \
  "https://foundryvtt.com/api/releases/download?version=${VERSION}&platform=linux" 2>&1)

if [ $? -ne 0 ]; then
  echo "Error: Failed to fetch download URL" >&2
  echo "Response: $json" >&2
  exit 1
fi

url=$(printf '%s' "$json" | jq -r '.url // .download // empty' 2>/dev/null)

if [ -z "$url" ] || [ "$url" = "null" ]; then
  echo "Error: Could not parse download URL for version ${VERSION}" >&2
  echo "API Response: $json" >&2
  exit 1
fi

echo "Download URL obtained successfully" >&2
printf '%s\n' "$url"