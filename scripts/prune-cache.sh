#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/logging.sh"

: "${FVTT_KEEP_PRIOR_COPIES}"
: "${FVTT_VERBOSE_LOGGING}"
: "${FVTT_LOG_BASE}"

FVTT_CACHE_DIR="/data/FVTT"
mkdir -p "$FVTT_CACHE_DIR"

mapfile -t archives < <(
  find "$FVTT_CACHE_DIR" -maxdepth 1 -type f \( \
    -name 'FoundryVTT-Node-*.zip' -o \
    -name 'Foundry-Node-*.zip' \
  \) | sort -Vr
)

if [ "${#archives[@]}" -le "$FVTT_KEEP_PRIOR_COPIES" ]; then
  log_info "No old zip files to prune"
  exit 0
fi

for archive in "${archives[@]:$FVTT_KEEP_PRIOR_COPIES}"; do
  log_info "Removing old zip: $(basename "$archive")"
  rm -f "$archive"
done

log_info "Pruning complete"