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

# Constants (from felddy's authenticate.ts)
BASE_URL="https://foundryvtt.com"
LOGIN_URL="${BASE_URL}/auth/login/"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# Extract build number from version (14.161 -> 161)
FOUNDRY_BUILD="${VERSION##*.}"

echo "Authenticating with foundryvtt.com..." >&2

# Step 1: Fetch CSRF tokens from main page
echo "Step 1: Fetching CSRF tokens..." >&2
csrf_response=$(curl -fsSL -c "$cookie_jar" -b "$cookie_jar" \
  -H "User-Agent: $USER_AGENT" \
  -H "DNT: 1" \
  -H "Upgrade-Insecure-Requests: 1" \
  "$BASE_URL" 2>&1)

if [ $? -ne 0 ]; then
  echo "Error: Failed to fetch CSRF tokens" >&2
  exit 1
fi

# Extract CSRF middleware token from HTML
csrfmiddlewaretoken=$(echo "$csrf_response" | grep -oP 'name="csrfmiddlewaretoken"\s+value="\K[^"]+' || echo "")

if [ -z "$csrfmiddlewaretoken" ]; then
  echo "Error: Could not find CSRF middleware token" >&2
  echo "Response snippet: $(echo "$csrf_response" | head -c 500)" >&2
  exit 1
fi

echo "CSRF token obtained: ${csrfmiddlewaretoken:0:16}..." >&2

# Step 2: Login with form data (matching felddy's exact approach)
echo "Step 2: Logging in as ${FOUNDRY_EMAIL}..." >&2

# Build form parameters (exactly as felddy does)
login_data="csrfmiddlewaretoken=${csrfmiddlewaretoken}&username=${FOUNDRY_EMAIL}&password=${FOUNDRY_PASSWORD}&next=%2F"

login_response=$(curl -fsSL -c "$cookie_jar" -b "$cookie_jar" \
  -w "\nHTTP_CODE:%{http_code}" \
  -H "User-Agent: $USER_AGENT" \
  -H "DNT: 1" \
  -H "Referer: $BASE_URL" \
  -H "Upgrade-Insecure-Requests: 1" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -X POST \
  -d "$login_data" \
  "$LOGIN_URL" 2>&1)

http_code=$(echo "$login_response" | grep "HTTP_CODE:" | cut -d: -f2)
response_body=$(echo "$login_response" | grep -v "HTTP_CODE:")

if [[ "$http_code" != "200" && "$http_code" != "302" ]]; then
  echo "Error: Login failed (HTTP ${http_code})" >&2
  echo "Response: $(echo "$response_body" | head -c 500)" >&2
  exit 1
fi

# Step 3: Verify we have a session cookie
sessionid=$(grep -oP 'sessionid\s+\K[^\s]+' "$cookie_jar" 2>/dev/null || echo "")

if [ -z "$sessionid" ]; then
  echo "Error: No session cookie found after login" >&2
  echo "Verify your credentials are correct" >&2
  exit 1
fi

echo "Login successful (sessionid: ${sessionid:0:16}...)" >&2

# Step 4: Fetch presigned release URL
# felddy uses: /releases/download?build=XXX&platform=node&response_type=json
echo "Step 3: Fetching download URL for build ${FOUNDRY_BUILD}..." >&2
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

# Parse the presigned URL from JSON
url=$(printf '%s' "$json" | jq -r '.url // empty' 2>/dev/null)

if [ -z "$url" ] || [ "$url" = "null" ]; then
  echo "Error: Could not parse download URL" >&2
  echo "API Response: $json" >&2
  exit 1
fi

echo "Download URL obtained successfully" >&2
printf '%s\n' "$url"