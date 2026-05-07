#!/usr/bin/env bash
set -euo pipefail

: "${FOUNDRY_KEEP_PRIOR:=5}"

FVTT_CACHE_DIR="/data/FVTT"

echo "Pruning old Foundry zip files (keeping ${FOUNDRY_KEEP_PRIOR} most recent)..."

mapfile -t versions < <(
  find "$FVTT_CACHE_DIR" -maxdepth 1 -type f -name 'foundryvtt-*.zip' \
    | sed 's|.*/foundryvtt-||' \
    | sed 's|\.zip$||' \
    | sort -Vr
)

if [ "${#versions[@]}" -eq 0 ]; then
  echo "No zip files found in cache."
  exit 0
fi

if [ "${#versions[@]}" -le "$FOUNDRY_KEEP_PRIOR" ]; then
  echo "No old zip files to prune."
  exit 0
fi

keep=()
for v in "${versions[@]}"; do
  keep+=("$v")
  [ "${#keep[@]}" -ge "$FOUNDRY_KEEP_PRIOR" ] && break
done

for zip in "$FVTT_CACHE_DIR"/foundryvtt-*.zip; do
  [ -f "$zip" ] || continue
  v="${zip##*/foundryvtt-}"
  v="${v%.zip}"
  skip=0
  for k in "${keep[@]}"; do
    [ "$v" = "$k" ] && skip=1
  done
  if [ "$skip" -eq 0 ]; then
    echo "Removing old zip: foundryvtt-${v}.zip"
    rm -f "$zip"
  fi
done

echo "Pruning complete."