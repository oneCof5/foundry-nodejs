#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?version required}"

: "${FOUNDRY_EMAIL:=}"
: "${FOUNDRY_PASSWORD:=}"
: "${FOUNDRY_LICENSE_KEY:=}"

if [ -n "${FOUNDRY_ZIP_URL:-}" ]; then
  printf '%s\n' "$FOUNDRY_ZIP_URL"
  exit 0
fi

cookie_jar="$(mktemp)"
trap 'rm -f "$cookie_jar"' EXIT

curl -fsSL -c "$cookie_jar" -b "$cookie_jar" https://foundryvtt.com/ >/dev/null

curl -fsSL -c "$cookie_jar" -b "$cookie_jar" \
  -d "email=${FOUNDRY_EMAIL}" \
  -d "password=${FOUNDRY_PASSWORD}" \
  https://foundryvtt.com/login >/dev/null

json="$(curl -fsSL -b "$cookie_jar" \
  "https://foundryvtt.com/api/download?version=${VERSION}&os=node")"

url="$(printf '%s' "$json" | jq -r '.url // .downloadUrl // empty')"
[ -n "$url" ] || { echo "could not resolve download url" >&2; exit 1; }
printf '%s\n' "$url"