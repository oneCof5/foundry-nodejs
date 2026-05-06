#!/usr/bin/env bash
set -euo pipefail

: "${APP_ROOT:=/foundry/FVTT}"
: "${FOUNDRY_KEEP_PRIOR:=5}"

mapfile -t versions < <(
  find "$APP_ROOT" -maxdepth 1 -type d -name 'foundryvtt-*' \
    | sed 's|.*/foundryvtt-||' \
    | sort -Vr
)

keep=()
for v in "${versions[@]}"; do
  keep+=("$v")
  [ "${#keep[@]}" -ge "$((FOUNDRY_KEEP_PRIOR + 1))" ] && break
done

for d in "$APP_ROOT"/foundryvtt-*; do
  [ -d "$d" ] || continue
  v="${d##*/foundryvtt-}"
  skip=0
  for k in "${keep[@]}"; do
    [ "$v" = "$k" ] && skip=1
  done
  [ "$skip" -eq 1 ] || rm -rf "$d"
done