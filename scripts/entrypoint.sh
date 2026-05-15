#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/logging.sh"

: "${FVTT_VERSION}"
: "${FVTT_KEEP_PRIOR_COPIES}"
: "${FVTT_AWS_CONFIG}"
: "${FVTT_COMPRESS_SOCKET}"
: "${FVTT_COMPRESS_STATIC}"
: "${FVTT_CSS_THEME}"
: "${FVTT_DELETE_NEDB}"
: "${FVTT_FULLSCREEN}"
: "${FVTT_HOSTNAME}"
: "${FVTT_HOT_RELOAD}"
: "${FVTT_LANGUAGE}"
: "${FVTT_LOCAL_HOSTNAME}"
: "${FVTT_NOUPDATE}"
: "${FVTT_PASSWORD_SALT}"
: "${FVTT_PORT}"
: "${FVTT_PROTOCOL}"
: "${FVTT_PROXY_PORT}"
: "${FVTT_PROXY_SSL}"
: "${FVTT_ROUTE_PREFIX}"
: "${FVTT_SERVICE_CONFIG}"
: "${FVTT_SSL_CERT_PATH}"
: "${FVTT_SSL_KEY_PATH}"
: "${FVTT_TELEMETRY_ENABLED}"
: "${FVTT_TEMP_DIR}"
: "${FVTT_UNIX_SOCKET}"
: "${FVTT_UPDATE_CHANNEL}"
: "${FVTT_UPNP_ENABLED}"
: "${FVTT_UPNP_LEASE_DURATION}"
: "${FVTT_WORLD}"
: "${FVTT_ADMIN_PASSWORD}"
: "${FVTT_NO_BACKUPS}"
: "${FVTT_LICENSE_KEY}"
: "${FVTT_RELEASE_URL}"
: "${FVTT_VERBOSE_LOGGING}"
: "${FVTT_LOG_MAX_SIZE_BYTES}"
: "${FVTT_LOG_KEEP_ROTATED}"
: "${FVTT_LOG_TO_STDERR}"
: "${FVTT_LOG_USE_COLOR}"
: "${FVTT_APP_DIR}"
: "${FVTT_DATA_DIR}"
: "${FVTT_LOGS_DIR}"
: "${PUID}"
: "${PGID}"

log_info  "--------------------------------------------------------------------"
log_info  "Foundry VTT Docker Container"
log_info  "--------------------------------------------------------------------"
log_info  "ENV                            VALUE"
log_info  "------------------------------ -------------------------------------"
log_info  "FVTT_APP_DIR                   $FVTT_APP_DIR"
log_info  "FVTT_DATA_DIR                  $FVTT_DATA_DIR"
log_info  "FVTT_LOGS_DIR                  $FVTT_LOGS_DIR"
log_info  "PUID                           $PUID"
log_info  "PGID                           $PGID"
log_info  "FVTT_VERSION                   $FVTT_VERSION"
log_info  "FVTT_PORT                      $FVTT_PORT"
log_info  "FVTT_VERBOSE_LOGGING           $FVTT_VERBOSE_LOGGING"
log_info  "FVTT_AWS_CONFIG                $FVTT_AWS_CONFIG"
log_info  "FVTT_COMPRESS_SOCKET           $FVTT_COMPRESS_SOCKET"
log_info  "FVTT_COMPRESS_STATIC           $FVTT_COMPRESS_STATIC"
log_info  "FVTT_CSS_THEME                 $FVTT_CSS_THEME"
log_info  "FVTT_DELETE_NEDB               $FVTT_DELETE_NEDB"
log_info  "FVTT_FULLSCREEN                $FVTT_FULLSCREEN"
log_info  "FVTT_HOSTNAME                  $FVTT_HOSTNAME"
log_info  "FVTT_HOT_RELOAD                $FVTT_HOT_RELOAD"
log_info  "FVTT_LANGUAGE                  $FVTT_LANGUAGE"
log_info  "FVTT_LOCAL_HOSTNAME            $FVTT_LOCAL_HOSTNAME"
log_info  "FVTT_PASSWORD_SALT             $FVTT_PASSWORD_SALT"
log_info  "FVTT_PORT                      $FVTT_PORT"
log_info  "FVTT_PROTOCOL                  $FVTT_PROTOCOL"
log_info  "FVTT_PROXY_PORT                $FVTT_PROXY_PORT"
log_info  "FVTT_PROXY_SSL                 $FVTT_PROXY_SSL"
log_info  "FVTT_ROUTE_PREFIX              $FVTT_ROUTE_PREFIX"
log_info  "FVTT_SERVICE_CONFIG            $FVTT_SERVICE_CONFIG"
log_info  "FVTT_SSL_CERT_PATH             $FVTT_SSL_CERT_PATH"
log_info  "FVTT_SSL_KEY_PATH              $FVTT_SSL_KEY_PATH"
log_info  "FVTT_TELEMETRY_ENABLED         $FVTT_TELEMETRY_ENABLED"
log_info  "FVTT_TEMP_DIR                  $FVTT_TEMP_DIR"
log_info  "FVTT_UNIX_SOCKET               $FVTT_UNIX_SOCKET"
log_info  "FVTT_UPDATE_CHANNEL            $FVTT_UPDATE_CHANNEL"
log_info  "FVTT_UPNP_ENABLED              $FVTT_UPNP_ENABLED"
log_info  "FVTT_UPNP_LEASE_DURATION       $FVTT_UPNP_LEASE_DURATION"
log_info  "FVTT_WORLD                     $FVTT_WORLD"
log_info  "FVTT_ADMIN_PASSWORD            $FVTT_ADMIN_PASSWORD"
log_info  "FVTT_NO_BACKUPS                $FVTT_NO_BACKUPS"
log_info  "--------------------------------------------------------------------"

CURRENT_PGID=$(id -g foundry)
CURRENT_PUID=$(id -u foundry)

if [ "$CURRENT_PGID" != "$PGID" ]; then
  log_info "Updating foundry group ID to $PGID"
  groupmod -o -g "$PGID" foundry
else
  log_debug "The foundry group ID is already $PGID"
fi

if [ "$CURRENT_PUID" != "$PUID" ]; then
  log_info "Updating foundry user ID to $PUID"
  usermod -o -u "$PUID" foundry
else
  log_debug "The foundry suer ID is already $PUID"
fi

log_info "Ensuring proper ownership of directories"

mkdir -p /foundryvtt /data /logs

USERGROUP_FILE="${FVTT_DATA_DIR}/.usergroup"
CURRENT_USERGROUP="${PUID}:${PGID}"
PREVIOUS_USERGROUP=""

if [ -f "$USERGROUP_FILE" ]; then
  PREVIOUS_USERGROUP="$(cat "$USERGROUP_FILE" 2>/dev/null || true)"
fi

if [ "$PREVIOUS_USERGROUP" = "$CURRENT_USERGROUP" ]; then
  log_info "Last applied PUID:PGID matches current value (${CURRENT_USERGROUP})"
else
  if [ "$FVTT_VERBOSE_LOGGING" = "true" ]; then
    changed_count="$(
      chown -c -R foundry:foundry /foundryvtt /data /logs 2>&1 \
        | tee /dev/stderr \
        | wc -l
    )"
    log_debug "Ownership updated for ${changed_count} path(s)"
  else
    chown -R foundry:foundry /foundryvtt /data /logs
  fi
  if [ -n "$PREVIOUS_USERGROUP" ]; then
    log_info "PUID:PGID changed from ${PREVIOUS_USERGROUP} to ${CURRENT_USERGROUP}"
  else
    log_info "No previous PUID:PGID marker found; applying ${CURRENT_USERGROUP}"
  fi
fi

# Confirm foundy:foundy can write logs.
chown -R foundry:foundry /logs

log_info "Switching to foundry user (UID:$PUID, GID:$PGID)"
exec gosu foundry /opt/foundry/scripts/bootstrap.sh