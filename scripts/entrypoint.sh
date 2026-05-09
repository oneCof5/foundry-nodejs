#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/logging.sh"

: "${PUID}"
: "${PGID}"
: "${FVTT_VERSION}"
: "${FVTT_PORT}"
: "${FVTT_VERBOSE_LOGGING}"
: "${FVTT_LOG_BASE}"

log_info  "--------------------------------------------------------------------"
log_info  "Foundry VTT Docker Container"
log_info  "--------------------------------------------------------------------"
log_info  "User UID (PUID):                $PUID"
log_info  "User GID (PGID):                $PGID"
log_info  "Version (FVTT_VERSION):         $FVTT_VERSION"
log_info  "Port (FVTT_PORT):               $FVTT_PORT"
log_debug "Verbose logging:                $FVTT_VERBOSE_LOGGING"
log_debug "Log base:                       $FVTT_LOG_BASE"
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

log_info "Switching to foundry user (UID:$PUID, GID:$PGID)"
exec gosu foundry /opt/foundry/scripts/bootstrap.sh