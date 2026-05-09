#!/usr/bin/env bash
set -euo pipefail

COLOR_RESET='\033[0m'
COLOR_DEBUG='\033[0;36m'
COLOR_DEFAULT='\033[0;37m'
SCRIPT_NAME="${0##*/}"
SCRIPT_NAME="${SCRIPT_NAME%.sh}"

: "${PUID:=911}"
: "${PGID:=911}"
: "${FOUNDRY_VERSION:=14.161}"
: "${FOUNDRY_PORT:=30000}"
: "${VERBOSE_LOGGING:=false}"

LOGS_DIR="/logs"
LOG_FILE="${LOGS_DIR}/foundry-$(date +%Y%m%d).log"
LOG_MAX_SIZE_BYTES=$((100 * 1024 * 1024))
LOG_KEEP_ROTATED=10

log_info() {
  echo -e "${COLOR_DEFAULT}${SCRIPT_NAME}: $*${COLOR_RESET}" >&2
}

log_debug() {
  if [ "$VERBOSE_LOGGING" = "true" ]; then
    echo -e "${COLOR_DEBUG}${SCRIPT_NAME}: $*${COLOR_RESET}" >&2
  fi
}

rotate_logs() {
  local file="$1"
  local size
  size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
  if [ "$size" -ge "$LOG_MAX_SIZE_BYTES" ]; then
    mv "$file" "${file}.$(date +%Y%m%d-%H%M%S)"
    touch "$file"
    ls -1t "${file}".* 2>/dev/null | tail -n +$((LOG_KEEP_ROTATED + 1)) | xargs -r rm -f
  fi
}

mkdir -p /logs /foundryvtt /data /data/Config /data/Data /data/Logs /data/Backups /data/FVTT
touch "$LOG_FILE"
rotate_logs "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

log_info "--------------------------------------------------------------------"
log_info "Foundry VTT Docker Container"
log_info "--------------------------------------------------------------------"
log_info "User UID (PUID):                   $PUID"
log_info "User GID (PGID):                   $PGID"
log_info "Version (FOUNDRY_VERSION):         $FOUNDRY_VERSION"
log_info "Port (FOUNDRY_PORT):               $FOUNDRY_PORT"
log_debug "Verbose logging:                   $VERBOSE_LOGGING"
log_info "--------------------------------------------------------------------"

CURRENT_PGID=$(id -g foundry)
CURRENT_PUID=$(id -u foundry)

if [ "$CURRENT_PGID" != "$PGID" ]; then
  log_info "Updating foundry group ID to $PGID"
  groupmod -o -g "$PGID" foundry
fi

if [ "$CURRENT_PUID" != "$PUID" ]; then
  log_info "Updating foundry user ID to $PUID"
  usermod -o -u "$PUID" foundry
fi

log_info "Ensuring proper ownership of directories"
if [ "$VERBOSE_LOGGING" = "true" ]; then
  chown -v -R foundry:foundry /foundryvtt /data /logs 2>&1 | while IFS= read -r line; do
    log_debug "$line"
  done
else
  chown -R foundry:foundry /foundryvtt /data /logs
fi

log_info "Switching to foundry user (UID:$PUID, GID:$PGID)"
exec gosu foundry /opt/foundry/scripts/bootstrap.sh