#!/usr/bin/env bash
set -euo pipefail

: "${FVTT_PORT}"

[ -f "/foundryvtt/main.js" ] || [ -f "/foundryvtt/resources/app/main.mjs" ] || exit 1
[ -f "/data/Config/admin.txt" ] || exit 1
[ -s "/data/Config/admin.txt" ] || exit 1
curl -f -s -o /dev/null "http://localhost:${FVTT_PORT}" || exit 1