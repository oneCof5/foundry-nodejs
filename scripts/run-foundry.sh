#!/usr/bin/env bash
set -euo pipefail

COLOR_RESET='\033[0m'
COLOR_DEBUG='\033[0;36m'
COLOR_DEFAULT='\033[0;37m'
SCRIPT_NAME="${0##*/}"
SCRIPT_NAME="${SCRIPT_NAME%.sh}"
VERSION="${1:?version required}"

: "${FOUNDRY_PORT:=30000}"
: "${FOUNDRY_WORLD:=}"
: "${FOUNDRY_HOSTNAME:=}"
: "${FOUNDRY_ROUTE_PREFIX:=}"
: "${FOUNDRY_PROXY_SSL:=false}"
: "${FOUNDRY_PROXY_PORT:=443}"
: "${FOUNDRY_MINIFY_STATIC_FILES:=true}"
: "${FOUNDRY_UPNP:=false}"
: "${FOUNDRY_COMPRESS_SOCKET:=false}"
: "${FOUNDRY_COMPRESS_WEBSOCKET:=false}"
: "${FOUNDRY_LANGUAGE:=en.core}"
: "${FOUNDRY_ADMIN_PASSWORD:=}"
: "${FOUNDRY_LICENSE_KEY:=}"
: "${VERBOSE_LOGGING:=false}"

log_info() {
  echo -e "${COLOR_DEFAULT}${SCRIPT_NAME}: $*${COLOR_RESET}" >&2
}

log_debug() {
  if [ "$VERBOSE_LOGGING" = "true" ]; then
    echo -e "${COLOR_DEBUG}${SCRIPT_NAME}: $*${COLOR_RESET}" >&2
  fi
}

FVTT_APP_DIR="/foundryvtt"
FVTT_DATA_DIR="/data"
CONFIG_DIR="${FVTT_DATA_DIR}/Config"
DATA_LOGS_DIR="${FVTT_DATA_DIR}/Logs"
OPTIONS_FILE="${CONFIG_DIR}/options.json"

mkdir -p "$CONFIG_DIR" "$DATA_LOGS_DIR"

if [ ! -f "$FVTT_APP_DIR/main.js" ] && [ ! -f "$FVTT_APP_DIR/resources/app/main.mjs" ]; then
  log_info "Error: Foundry VTT installation not found at ${FVTT_APP_DIR}" >&2
  exit 1
fi

if [ -n "$FOUNDRY_ADMIN_PASSWORD" ] && [ ! -f "$CONFIG_DIR/admin.txt" ]; then
  log_info "Setting administrator password"
  printf '%s' "$FOUNDRY_ADMIN_PASSWORD" > "$CONFIG_DIR/admin.txt"
fi

if [ ! -f "$CONFIG_DIR/admin.txt" ] || [ ! -s "$CONFIG_DIR/admin.txt" ]; then
  log_info "Error: admin password is required but not configured" >&2
  exit 1
fi

if [ -n "$FOUNDRY_LICENSE_KEY" ]; then
  cat > "$CONFIG_DIR/license.json" <<JSON
{
  "license": "${FOUNDRY_LICENSE_KEY}"
}
JSON
fi

if [ ! -f "$OPTIONS_FILE" ]; then
  log_info "Creating options.json from environment"
  jq -n \
    --arg hostname "$FOUNDRY_HOSTNAME" \
    --arg routePrefix "$FOUNDRY_ROUTE_PREFIX" \
    --arg language "$FOUNDRY_LANGUAGE" \
    --arg world "$FOUNDRY_WORLD" \
    --argjson port "$FOUNDRY_PORT" \
    --argjson proxySSL "$([ "$FOUNDRY_PROXY_SSL" = "true" ] && echo true || echo false)" \
    --argjson proxyPort "$FOUNDRY_PROXY_PORT" \
    --argjson minifyStaticFiles "$([ "$FOUNDRY_MINIFY_STATIC_FILES" = "true" ] && echo true || echo false)" \
    --argjson upnp "$([ "$FOUNDRY_UPNP" = "true" ] && echo true || echo false)" \
    --argjson compressSocket "$([ "$FOUNDRY_COMPRESS_SOCKET" = "true" ] && echo true || echo false)" \
    --argjson compressWebsocket "$([ "$FOUNDRY_COMPRESS_WEBSOCKET" = "true" ] && echo true || echo false)" \
    '
    {
      port: $port,
      upnp: $upnp,
      proxySSL: $proxySSL,
      proxyPort: $proxyPort,
      minifyStaticFiles: $minifyStaticFiles,
      compressSocket: $compressSocket,
      compressWebsocket: $compressWebsocket,
      language: $language
    }
    + (if $hostname != "" then {hostname: $hostname} else {} end)
    + (if $routePrefix != "" then {routePrefix: $routePrefix} else {} end)
    + (if $world != "" then {world: $world} else {} end)
    ' > "$OPTIONS_FILE"
fi

log_info "Starting Foundry VTT ${VERSION}"
log_info "Port: ${FOUNDRY_PORT}"
log_info "Data Path: ${FVTT_DATA_DIR}"
log_info "Logs Path: /logs"

cd "$FVTT_APP_DIR"

args=(
  --dataPath="$FVTT_DATA_DIR"
  --port="$FOUNDRY_PORT"
)

if [ -n "$FOUNDRY_WORLD" ]; then
  args+=(--world="$FOUNDRY_WORLD")
fi

if [ -f "$FVTT_APP_DIR/main.js" ]; then
  exec node main.js "${args[@]}"
else
  exec node resources/app/main.mjs "${args[@]}"
fi