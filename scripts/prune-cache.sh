#!/usr/bin/env bash
set -euo pipefail

COLOR_RESET='\033[0m'
COLOR_DEFAULT='\033[0;37m'
SCRIPT_NAME="${0##*/}"
SCRIPT_NAME="${SCRIPT_NAME%.sh}"

: "${FOUNDRY_KEEP_PRIOR:=5}"

log_info() {
  echo -e "${COLOR_DEFAULT}${SCRIPT_NAME}: $*${COLOR_RESET}" >&2
}

FVTT_CACHE_DIR="/data/FVTT"
mkdir -p "$FVTT_CACHE_DIR"

mapfile -t archives < <(
  find "$FVTT_CACHE_DIR" -maxdepth 1 -type f \( \
    -name 'FoundryVTT-Node-*.zip' -o \
    -name 'Foundry-Node-*.zip' \
  \) | sort -Vr
)

if [ "${#archives[@]}" -le "$FOUNDRY_KEEP_PRIOR" ]; then
  log_info "No old zip files to prune"
  exit 0
fi

for archive in "${archives[@]:$FOUNDRY_KEEP_PRIOR}"; do
  log_info "Removing old zip: $(basename "$archive")"
  rm -f "$archive"
done

log_info "Pruning complete"