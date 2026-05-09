#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/logging.sh"

VERSION="${1:?version required}"

: "${FVTT_PORT}"
: "${FVTT_WORLD}"
: "${FVTT_HOSTNAME}"
: "${FVTT_ROUTE_PREFIX}"
: "${FVTT_PROXY_SSL}"
: "${FVTT_PROXY_PORT"
: "${FVTT_MINIFY_STATIC_FILES"
: "${FVTT_NOUPDATE"
: "${FVTT_UPNP_ENABLED"
: "${FVTT_COMPRESS_SOCKET"
: "${FVTT_COMPRESS_STATIC"
: "${FVTT_LANGUAGE"
: "${FVTT_ADMIN_PASSWORD"
: "${FVTT_LICENSE_KEY"
: "${FVTT_VERBOSE_LOGGING"
: "${FVTT_LOG_BASE}"
: "${FVTT_APP_DIR}"
: "${FVTT_DATA_DIR}"

CONFIG_DIR="${FVTT_DATA_DIR}/Config"
OPTIONS_FILE="${CONFIG_DIR}/options.json"

if [ ! -f "$FVTT_APP_DIR/main.js" ] && [ ! -f "$FVTT_APP_DIR/resources/app/main.mjs" ]; then
  log_info "Error: Foundry VTT installation not found at ${FVTT_APP_DIR}" >&2
  exit 1
fi

if [ -n "$FVTT_ADMIN_PASSWORD" ] && [ ! -f "$CONFIG_DIR/admin.txt" ]; then
  log_info "Setting administrator password"
  printf '%s' "$FVTT_ADMIN_PASSWORD" > "$CONFIG_DIR/admin.txt"
  log_debug "FVTT_ADMIN_PASSWORD:$FVTT_ADMIN_PASSWORD in "$CONFIG_DIR/admin.txt"
fi

if [ ! -f "$CONFIG_DIR/admin.txt" ] || [ ! -s "$CONFIG_DIR/admin.txt" ]; then
  log_error "Error: admin password is required but not configured" >&2
  exit 1
fi

if [ -z "${FVTT_LICENSE_KEY:-}" ]; then
  log_error "FVTT_LICENSE_KEY is required but is missing or empty"
  exit 1
fi

LICENSE_FILE="${CONFIG_DIR}/license.json"
if [ -f "$LICENSE_FILE" ]; then
  log_info "Existing license.json found at $LICENSE_FILE; leaving it unchanged"
else
  jq -n --arg license "$FVTT_LICENSE_KEY" '{license: $license}' > "$LICENSE_FILE"
  log_info "Created license.json at $LICENSE_FILE"
  leg_debug "Wrote {license: FVTT_LICENSE_KEY}"
fi

OPTIONS_FILE="${CONFIG_DIR}/options.json"
if [ ! -f "$OPTIONS_FILE" ]; then
  log_info "Creating options.json from environment"
  jq -n \
    --argjson awsConfig        "${FVTT_AWS_CONFIG}" \
    --argjson compressSocket   "${FVTT_COMPRESS_SOCKET}" \
    --argjson compressStatic   "${FVTT_COMPRESS_STATIC}" \
    --arg    cssTheme          "${FVTT_CSS_THEME}" \
    --argjson deleteNEDB       "${FVTT_DELETE_NEDB}" \
    --argjson fullscreen       "${FVTT_FULLSCREEN}" \
    --arg    hostname          "${FVTT_HOSTNAME}" \
    --argjson hotReload        "${FVTT_HOT_RELOAD}" \
    --arg    language          "${FVTT_LANGUAGE}" \
    --arg    localHostname     "${FVTT_LOCAL_HOSTNAME" \
    --arg    passwordSalt      "${FVTT_PASSWORD_SALT" \
    --argjson port             "${FVTT_PORT}" \
    --argjson protocol         "${FVTT_PROTOCOL" \
    --arg    proxyPort         "${FVTT_PROXY_PORT" \
    --argjson proxySSL         "${FVTT_PROXY_SSL" \
    --arg    routePrefix       "${FVTT_ROUTE_PREFIX}" \
    --arg    serviceConfig     "${FVTT_SERVICE_CONFIG" \
    --arg    sslCert           "${FVTT_SSL_CERT_PATH" \
    --arg    sslKey            "${FVTT_SSL_KEY_PATH" \
    --argjson telemetry        "${FVTT_TELEMETRY_ENABLED" \
    --arg    tempDir           "${FVTT_TEMP_DIR" \
    --arg    unixSocket        "${FVTT_UNIX_SOCKET}" \
    --arg    updateChannel     "${FVTT_UPDATE_CHANNEL}" \
    --argjson upnp             "${FVTT_UPNP_ENABLED}" \
    --arg    upnpLeaseDuration "${FVTT_UPNP_LEASE_DURATION" \
    --arg    world             "${FVTT_WORLD" \
    --arg    adminPassword     "${FVTT_ADMIN_PASSWORD}" \
    --argjson noBackups        "${FVTT_NO_BACKUPS}" \
    '{
      awsConfig:          ($awsConfig        | if . == "null" then null else . end),
      compressSocket:     $compressSocket,
      compressStatic:     $compressStatic,
      cssTheme:           $cssTheme,
      deleteNEDB:         $deleteNEDB,
      fullscreen:         $fullscreen,
      hostname:           $hostname,
      hotReload:          $hotReload,
      language:           $language,
      localHostname:      (if $localHostname    == "null" then null else $localHostname    end),
      passwordSalt:       (if $passwordSalt     == "null" then null else $passwordSalt     end),
      port:               $port,
      protocol:           $protocol,
      proxyPort:          (if $proxyPort        == "null" then null else ($proxyPort | tonumber) end),
      proxySSL:           $proxySSL,
      routePrefix:        (if $routePrefix      == "null" then null else $routePrefix      end),
      serviceConfig:      (if $serviceConfig    == "null" then null else $serviceConfig    end),
      sslCert:            (if $sslCert          == "null" then null else $sslCert          end),
      sslKey:             (if $sslKey           == "null" then null else $sslKey           end),
      telemetry:          $telemetry,
      tempDir:            (if $tempDir          == "null" then null else $tempDir          end),
      unixSocket:         (if $unixSocket       == "null" then null else $unixSocket       end),
      updateChannel:      $updateChannel,
      upnp:               $upnp,
      upnpLeaseDuration:  (if $upnpLeaseDuration== "null" then null else ($upnpLeaseDuration|tonumber) end),
      world:              $world,
      adminPassword:      $adminPassword,
      noBackups:          $noBackups
    }' > "$OPTIONS_FILE"
fi

log_info "Starting Foundry VTT ${VERSION}"
log_info "Port: ${FVTT_PORT}"
log_info "Data Path: ${FVTT_DATA_DIR}"
log_info "Logs Path: ${FVTT_LOGS_DIR}"

cd "$FVTT_APP_DIR"

args=(
  --dataPath="$FVTT_DATA_DIR"
  --port="$FVTT_PORT"
)
if [ -n "$FVTT_NOUPDATE" ]; then
  args+=(--noupdate="$FVTT_NOUPDATE")
fi

if [ -n "$FVTT_WORLD" ]; then
  args+=(--world="$FVTT_WORLD")
fi

if [ -f "$FVTT_APP_DIR/main.js" ]; then
  exec node main.js "${args[@]}"
else
  exec node resources/app/main.mjs "${args[@]}"
fi