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

echo "Authenticating with foundryvtt.com..." >&2

cookie_jar="$(mktemp)"
trap 'rm -f "$cookie_jar"' EXIT

# Step 1: Get the login page to establish session
echo "Getting session cookie..." >&2
curl -fsSL -c "$cookie_jar" -b "$cookie_jar" \
  https://foundryvtt.com/auth/login >/dev/null

# Step 2: Submit login form
echo "Logging in..." >&2
login_response=$(curl -fsSL -c "$cookie_jar" -b "$cookie_jar" \
  -L \
  -d "email=${FOUNDRY_EMAIL}" \
  -d "password=${FOUNDRY_PASSWORD}" \
  https://foundryvtt.com/auth/login 2>&1)

# Step 3: Verify login by checking if we can access the API
echo "Verifying authentication..." >&2
auth_check=$(curl -fsSL -b "$cookie_jar" \
  https://foundryvtt.com/api/me 2>&1 || echo "AUTH_FAILED")

if [[ "$auth_check" == "AUTH_FAILED" ]] || [[ "$auth_check" == *"error"* ]]; then
  echo "Error: Authentication failed" >&2
  echo "Check your email and password" >&2
  exit 1
fi

# Step 4: Request download URL
echo "Requesting download URL for version ${VERSION}..." >&2
json=$(curl -fsSL -b "$cookie_jar" \
  "https://foundryvtt.com/api/releases/download?version=${VERSION}&platform=linux" 2>&1)

if [ $? -ne 0 ]; then
  echo "Error: Failed to fetch download URL" >&2
  exit 1
fi

# Step 5: Parse the URL
url=$(printf '%s' "$json" | jq -r '.url // .download // empty' 2>/dev/null)

if [ -z "$url" ] || [ "$url" = "null" ]; then
  echo "Error: Could not parse download URL" >&2
  echo "API returned: $json" >&2
  exit 1
fi

echo "Download URL obtained successfully" >&2
printf '%s\n' "$url"