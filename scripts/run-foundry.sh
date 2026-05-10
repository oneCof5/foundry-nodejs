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
: "${FVTT_PROXY_PORT}"
: "${FVTT_MINIFY_STATIC_FILES}"
: "${FVTT_NOUPDATE}"
: "${FVTT_UPNP_ENABLED}"
: "${FVTT_COMPRESS_SOCKET}"
: "${FVTT_COMPRESS_STATIC}"
: "${FVTT_LANGUAGE}"
: "${FVTT_ADMIN_PASSWORD}"
: "${FVTT_LICENSE_KEY}"
: "${FVTT_PASSWORD_SALT}"
: "${FVTT_VERBOSE_LOGGING}"
: "${FVTT_LOG_BASE}"
: "${FVTT_APP_DIR}"
: "${FVTT_DATA_DIR}"

CONFIG_DIR="${FVTT_DATA_DIR}/Config"
OPTIONS_FILE="${CONFIG_DIR}/options.json"

if [ ! -f "$FVTT_APP_DIR/main.js" ] && [ ! -f "$FVTT_APP_DIR/resources/app/main.mjs" ]; then
  log_info "Error: Foundry VTT installation not found at ${FVTT_APP_DIR}" >&2
  exit 1
fi

log_info "Setting administrator password"

mkdir -p "$CONFIG_DIR"
ADMIN_FILE="$CONFIG_DIR/admin.txt"

encrypt_admin_password() {
  plaintext="$1"
  salt="${FVTT_PASSWORD_SALT}"

  printf '%s' "$plaintext" | tr -d '\r\n' | {
    IFS= read -r trimmed
    openssl kdf -keylen 64 \
      -kdfopt digest:SHA512 \
      -kdfopt pass:"$trimmed" \
      -kdfopt salt:"$salt" \
      -kdfopt iter:1000 \
      PBKDF2
  } \
  | tr -d '\r\n' \
  | tr -d ':' \
  | tr '[:upper:]' '[:lower:]'
}

# Ensure admin.txt exists
if [ ! -f "$ADMIN_FILE" ]; then
  : > "$ADMIN_FILE"
  log_debug "Created empty admin password file at $ADMIN_FILE"
fi

CURRENT_ADMIN_PASSWORD="$(cat "$ADMIN_FILE" 2>/dev/null || true)"

if [ -z "${CURRENT_ADMIN_PASSWORD:-}" ]; then
  log_debug "Existing admin.txt is empty"
else
  log_debug "Existing admin password hash loaded from $ADMIN_FILE"
fi

if [ -z "${FVTT_ADMIN_PASSWORD:-}" ]; then
  log_warn "FVTT_ADMIN_PASSWORD is not set or empty; leaving existing admin password as-is"
else
  ENCRYPTED_ADMIN_PASSWORD="$(encrypt_admin_password "$FVTT_ADMIN_PASSWORD")"

  if [ "$ENCRYPTED_ADMIN_PASSWORD" != "$CURRENT_ADMIN_PASSWORD" ]; then
    printf '%s' "$ENCRYPTED_ADMIN_PASSWORD" > "$ADMIN_FILE"
    log_info "Updated administrator password hash in $ADMIN_FILE"
  else
    log_debug "Administrator password hash already matches existing value in $ADMIN_FILE; no update needed"
  fi
fi

if [ ! -s "$ADMIN_FILE" ]; then
  log_warn "Error: admin password is not configured (empty $ADMIN_FILE)" >&2
  exit 1
fi

if [ -z "${FVTT_LICENSE_KEY:-}" ]; then
  log_warn "FVTT_LICENSE_KEY is not provided"
  exit 1
fi

log_info "Setting license key"

strip_hyphens() {
  printf '%s\n' "$1" | tr -d '-'
}

LICENSE_FILE="${CONFIG_DIR}/license.json"

if [ -z "${FVTT_LICENSE_KEY:-}" ]; then
  log_warn "FVTT_LICENSE_KEY is missing or empty"
fi

mkdir -p "$CONFIG_DIR"

# Ensure license.json exists (create minimal skeleton if missing)
if [ ! -f "$LICENSE_FILE" ] || [ ! -s "$LICENSE_FILE" ]; then
  log_info "license.json not found or empty; creating new skeleton at $LICENSE_FILE"
  cat >"$LICENSE_FILE" <<'JSON'
{
  "host": "",
  "license": "",
  "version": "",
  "time": "",
  "signature": ""
}
JSON
fi

# Normalize env var and compare/update only license field
normalized_license="$(strip_hyphens "${FVTT_LICENSE_KEY}")"

current_license="$(
  jq -r '.license // ""' "$LICENSE_FILE" 2>/dev/null || printf ''
)"

if [ "$normalized_license" = "$current_license" ]; then
  log_debug "license.json license field already matches normalized FVTT_LICENSE_KEY; no update needed"
else
  log_info "Updating license field in license.json"
  tmp_file="${LICENSE_FILE}.tmp"

  jq --arg license "$normalized_license" '
    .license = $license
  ' "$LICENSE_FILE" > "$tmp_file"

  mv "$tmp_file" "$LICENSE_FILE"
  log_debug "Updated license field in $LICENSE_FILE to normalized value"
fi

# Build the options
OPTIONS_FILE="${CONFIG_DIR}/options.json"
OPTIONS_TMP_FILE="${OPTIONS_FILE}.tmp"

# Ensure file exists and contains valid JSON object
if [ ! -f "$OPTIONS_FILE" ] || [ ! -s "$OPTIONS_FILE" ]; then
  log_info "options.json missing or empty; creating new file at $OPTIONS_FILE"
  printf '{}\n' > "$OPTIONS_FILE"
elif ! jq empty "$OPTIONS_FILE" >/dev/null 2>&1; then
  log_warn "Existing $OPTIONS_FILE is invalid JSON; resetting to empty object"
  printf '{}\n' > "$OPTIONS_FILE"
fi

# Build desired config object from environment, then merge into existing file
#  --arg     passwordSalt      "${FVTT_PASSWORD_SALT}" \
#  --arg     adminPassword     "${FVTT_ADMIN_PASSWORD}" \
#      passwordSalt:      ($passwordSalt      | if . == "" or . == "null" then null else . end),
#      adminPassword:     ($adminPassword     | if . == "" or . == "null" then null else . end),
jq \
  --arg     awsConfig         "${FVTT_AWS_CONFIG}" \
  --argjson compressSocket    "${FVTT_COMPRESS_SOCKET}" \
  --argjson compressStatic    "${FVTT_COMPRESS_STATIC}" \
  --arg     cssTheme          "${FVTT_CSS_THEME}" \
  --argjson deleteNEDB        "${FVTT_DELETE_NEDB}" \
  --argjson fullscreen        "${FVTT_FULLSCREEN}" \
  --arg     hostname          "${FVTT_HOSTNAME}" \
  --argjson hotReload         "${FVTT_HOT_RELOAD}" \
  --arg     language          "${FVTT_LANGUAGE}" \
  --arg     localHostname     "${FVTT_LOCAL_HOSTNAME}" \
  --argjson port              "${FVTT_PORT}" \
  --arg     protocol          "${FVTT_PROTOCOL}" \
  --arg     proxyPort         "${FVTT_PROXY_PORT}" \
  --argjson proxySSL          "${FVTT_PROXY_SSL}" \
  --arg     routePrefix       "${FVTT_ROUTE_PREFIX}" \
  --arg     serviceConfig     "${FVTT_SERVICE_CONFIG}" \
  --arg     sslCert           "${FVTT_SSL_CERT_PATH}" \
  --arg     sslKey            "${FVTT_SSL_KEY_PATH}" \
  --argjson telemetry         "${FVTT_TELEMETRY_ENABLED}" \
  --arg     tempDir           "${FVTT_TEMP_DIR}" \
  --arg     unixSocket        "${FVTT_UNIX_SOCKET}" \
  --arg     updateChannel     "${FVTT_UPDATE_CHANNEL}" \
  --argjson upnp              "${FVTT_UPNP_ENABLED}" \
  --arg     upnpLeaseDuration "${FVTT_UPNP_LEASE_DURATION}" \
  --arg     world             "${FVTT_WORLD}" \
  --argjson noBackups         "${FVTT_NO_BACKUPS}" \
  '
  . as $current
  | ($current + {
      awsConfig:         ($awsConfig         | if . == "" or . == "null" then null else . end),
      compressSocket:    $compressSocket,
      compressStatic:    $compressStatic,
      cssTheme:          $cssTheme,
      deleteNEDB:        $deleteNEDB,
      fullscreen:        $fullscreen,
      hostname:          $hostname,
      hotReload:         $hotReload,
      language:          $language,
      localHostname:     ($localHostname     | if . == "" or . == "null" then null else . end),
      port:              $port,
      protocol:          ($protocol          | if . == "" or . == "null" then null else . end),
      proxyPort:         ($proxyPort         | if . == "" or . == "null" then null else (.|tonumber) end),
      proxySSL:          $proxySSL,
      routePrefix:       ($routePrefix       | if . == "" or . == "null" then null else . end),
      serviceConfig:     ($serviceConfig     | if . == "" or . == "null" then null else . end),
      sslCert:           ($sslCert           | if . == "" or . == "null" then null else . end),
      sslKey:            ($sslKey            | if . == "" or . == "null" then null else . end),
      telemetry:         $telemetry,
      tempDir:           ($tempDir           | if . == "" or . == "null" then null else . end),
      unixSocket:        ($unixSocket        | if . == "" or . == "null" then null else . end),
      updateChannel:     $updateChannel,
      upnp:              $upnp,
      upnpLeaseDuration: ($upnpLeaseDuration | if . == "" or . == "null" then null else (.|tonumber) end),
      world:             ($world             | if . == "" or . == "null" then null else . end),
      noBackups:         $noBackups
    }) as $updated
  | $updated
  ' "$OPTIONS_FILE" > "$OPTIONS_TMP_FILE"

if cmp -s "$OPTIONS_FILE" "$OPTIONS_TMP_FILE"; then
  rm -f "$OPTIONS_TMP_FILE"
  log_debug "No changes detected for $OPTIONS_FILE"
else
  mv "$OPTIONS_TMP_FILE" "$OPTIONS_FILE"
  log_info "Upserted environment values into $OPTIONS_FILE"
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