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

# Constants
BASE_URL="https://foundryvtt.com"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# Extract build number from version (14.161 -> 161)
FOUNDRY_BUILD="${VERSION##*.}"

echo "Authenticating with foundryvtt.com..." >&2

# Step 1: Get login page and CSRF token
echo "Step 1: Getting login page..." >&2
login_page=$(curl -fsSL -c "$cookie_jar" -b "$cookie_jar" \
  -H "User-Agent: $USER_AGENT" \
  "${BASE_URL}/auth/login/" 2>&1)

if [ $? -ne 0 ]; then
  echo "Error: Failed to fetch login page" >&2
  exit 1
fi

# Extract CSRF token from login page
csrftoken=$(echo "$login_page" | grep -oP 'name=["\047]csrfmiddlewaretoken["\047]\s+value=["\047]\K[^"\047]+' | head -n1)

if [ -z "$csrftoken" ]; then
  # Try alternate pattern - get from cookie
  csrftoken=$(grep -oP 'csrftoken\s+\K[^\s]+' "$cookie_jar" 2>/dev/null || echo "")
fi

if [ -z "$csrftoken" ]; then
  echo "Error: Could not extract CSRF token" >&2
  echo "Cookie jar contents:" >&2
  cat "$cookie_jar" >&2
  exit 1
fi

echo "CSRF token: ${csrftoken:0:16}..." >&2

# Step 2: Perform login
echo "Step 2: Logging in..." >&2

login_response=$(curl -fsSL -c "$cookie_jar" -b "$cookie_jar" \
  -w "\nHTTP_CODE:%{http_code}\nREDIRECT_URL:%{redirect_url}" \
  -H "User-Agent: $USER_AGENT" \
  -H "Referer: ${BASE_URL}/auth/login/" \
  -H "Origin: $BASE_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -X POST \
  --data-urlencode "csrfmiddlewaretoken=${csrftoken}" \
  --data-urlencode "username=${FOUNDRY_EMAIL}" \
  --data-urlencode "password=${FOUNDRY_PASSWORD}" \
  --data-urlencode "next=/" \
  "${BASE_URL}/auth/login/" 2>&1)

http_code=$(echo "$login_response" | grep "HTTP_CODE:" | cut -d: -f2)
redirect_url=$(echo "$login_response" | grep "REDIRECT_URL:" | cut -d: -f2-)
response_body=$(echo "$login_response" | grep -v "HTTP_CODE:" | grep -v "REDIRECT_URL:")

echo "Login response code: $http_code" >&2
echo "Redirect URL: $redirect_url" >&2

# Check if login was successful
if [[ "$http_code" != "200" && "$http_code" != "302" && "$http_code" != "301" ]]; then
  echo "Error: Login failed (HTTP ${http_code})" >&2
  echo "Response body: $(echo "$response_body" | head -c 500)" >&2
  exit 1
fi

# Verify session cookie exists
if ! grep -q "sessionid" "$cookie_jar"; then
  echo "Error: No session cookie after login" >&2
  echo "Cookies received:" >&2
  cat "$cookie_jar" >&2
  exit 1
fi

echo "Login successful" >&2

# Step 3: Get download URL
echo "Step 3: Fetching download URL for build ${FOUNDRY_BUILD}..." >&2
RELEASE_URL="${BASE_URL}/releases/download?build=${FOUNDRY_BUILD}&platform=node&response_type=json"

json_response=$(curl -fsSL -b "$cookie_jar" \
  -w "\nHTTP_CODE:%{http_code}" \
  -H "User-Agent: $USER_AGENT" \
  -H "Referer: $BASE_URL" \
  "$RELEASE_URL" 2>&1)

download_http_code=$(echo "$json_response" | grep "HTTP_CODE:" | cut -d: -f2)
json=$(echo "$json_response" | grep -v "HTTP_CODE:")

if [[ "$download_http_code" != "200" ]]; then
  echo "Error: Failed to get download URL (HTTP ${download_http_code})" >&2
  echo "Response: $json" >&2
  exit 1
fi

# Parse URL
url=$(printf '%s' "$json" | jq -r '.url // empty' 2>/dev/null)

if [ -z "$url" ] || [ "$url" = "null" ]; then
  echo "Error: Could not parse download URL" >&2
  echo "Response: $json" >&2
  exit 1
fi

echo "Download URL obtained" >&2
printf '%s\n' "$url"