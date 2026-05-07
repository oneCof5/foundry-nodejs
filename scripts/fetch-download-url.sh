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

cookie_jar="$(mktemp)"
trap 'rm -f "$cookie_jar"' EXIT

# Constants (matching felddy implementation)
BASE_URL="https://foundryvtt.com"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# Extract build number from version (x.yyy -> yyy)
# FoundryVTT versions look like 14.161 where 161 is the build
FOUNDRY_BUILD="${VERSION##*.}"

echo "Authenticating with foundryvtt.com..." >&2

# Step 1: Initial visit to get session cookies
curl -fsSL -c "$cookie_jar" -b "$cookie_jar" \
  -H "User-Agent: $USER_AGENT" \
  -H "DNT: 1" \
  -H "Upgrade-Insecure-Requests: 1" \
  "$BASE_URL" >/dev/null

# Step 2: Login
echo "Logging in..." >&2
login_response=$(curl -fsSL -c "$cookie_jar" -b "$cookie_jar" \
  -w "\nHTTP_CODE:%{http_code}" \
  -H "User-Agent: $USER_AGENT" \
  -H "DNT: 1" \
  -H "Referer: $BASE_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -X POST \
  -d "userid=${FOUNDRY_EMAIL}" \
  -d "password=${FOUNDRY_PASSWORD}" \
  "$BASE_URL/auth/login" 2>&1)

http_code=$(echo "$login_response" | grep "HTTP_CODE:" | cut -d: -f2)

# If that fails, try with email
if [[ "$http_code" != "200" && "$http_code" != "302" ]]; then
  echo "Trying alternate login method..." >&2
  login_response=$(curl -fsSL -c "$cookie_jar" -b "$cookie_jar" \
    -w "\nHTTP_CODE:%{http_code}" \
    -H "User-Agent: $USER_AGENT" \
    -X POST \
    -d "email=${FOUNDRY_EMAIL}" \
    -d "password=${FOUNDRY_PASSWORD}" \
    "$BASE_URL/auth/login" 2>&1)
  
  http_code=$(echo "$login_response" | grep "HTTP_CODE:" | cut -d: -f2)
fi

if [[ "$http_code" != "200" && "$http_code" != "302" ]]; then
  echo "Error: Login failed (HTTP ${http_code})" >&2
  exit 1
fi

echo "Login successful" >&2

# Step 3: Fetch presigned release URL (using felddy's endpoint)
# Note: felddy uses build number and platform=node, response_type=json
echo "Fetching presigned release URL for build ${FOUNDRY_BUILD}..." >&2
RELEASE_URL="${BASE_URL}/releases/download?build=${FOUNDRY_BUILD}&platform=node&response_type=json"

json_response=$(curl -fsSL -b "$cookie_jar" \
  -w "\nHTTP_CODE:%{http_code}" \
  -H "User-Agent: $USER_AGENT" \
  -H "DNT: 1" \
  -H "Referer: $BASE_URL" \
  -H "Upgrade-Insecure-Requests: 1" \
  "$RELEASE_URL" 2>&1)

download_http_code=$(echo "$json_response" | grep "HTTP_CODE:" | cut -d: -f2)
json=$(echo "$json_response" | grep -v "HTTP_CODE:")

if [[ "$download_http_code" != "200" ]]; then
  echo "Error: Failed to fetch release URL (HTTP ${download_http_code})" >&2
  echo "Response: $json" >&2
  exit 1
fi

# Parse the presigned URL from JSON response
url=$(printf '%s' "$json" | jq -r '.url // empty' 2>/dev/null)

if [ -z "$url" ] || [ "$url" = "null" ]; then
  echo "Error: Could not parse presigned URL from response" >&2
  echo "API Response: $json" >&2
  exit 1
fi

echo "Presigned URL obtained successfully" >&2
printf '%s\n' "$url"