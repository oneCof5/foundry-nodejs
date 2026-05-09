#!/usr/bin/env bash
set -euo pipefail

: "${FOUNDRY_PORT:=30000}"

[ -f "/foundryvtt/main.js" ] || [ -f "/foundryvtt/resources/app/main.mjs" ] || exit 1
[ -f "/data/Config/admin.txt" ] || exit 1
[ -s "/data/Config/admin.txt" ] || exit 1
curl -f -s -o /dev/null "http://localhost:${FOUNDRY_PORT}" || exit 1