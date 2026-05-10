#!/usr/bin/env bash

if [[ "${__LOGGING_SH_LOADED:-0}" -eq 1 ]]; then
  return 0 2>/dev/null || exit 0
fi
__LOGGING_SH_LOADED=1

: "${FVTT_VERBOSE_LOGGING}"
: "${FVTT_LOGS_DIR}"
: "${FVTT_LOG_MAX_SIZE_BYTES}"
: "${FVTT_LOG_KEEP_ROTATED}"
: "${FVTT_LOG_TO_STDERR}"
: "${FVTT_LOG_USE_COLOR}"

COLOR_RESET=$'\033[0m'
COLOR_DEBUG=$'\033[0;36m'
COLOR_INFO=$'\033[0;37m'
COLOR_WARN=$'\033[1;33m'
COLOR_ERROR=$'\033[0;31m'

FVTT_LOG_BASE="foundryvtt"

log_init() {
  mkdir -p "${FVTT_LOGS_DIR}"
  LOG_FILE="${LOG_FILE:-${FVTT_LOGS_DIR}/${FVTT_LOG_BASE}-$(date +%Y%m%d).log}"
  touch "${LOG_FILE}"
}

_get_caller_context() {
  local this_file src func line i script_name

  this_file="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"

  for ((i=1; i<${#BASH_SOURCE[@]}; i++)); do
    src="${BASH_SOURCE[$i]}"

    if [[ -n "$src" && "$src" != "$this_file" ]]; then
      script_name="${src##*/}"
      script_name="${script_name%.sh}"

      func="${FUNCNAME[$i]:-main}"

      if (( i > 0 )) && [[ -n "${BASH_LINENO[$((i-1))]:-}" ]]; then
        line="${BASH_LINENO[$((i-1))]}"
      else
        line="0"
      fi

      printf '%s:%s:%s' "$script_name" "$func" "$line"
      return 0
    fi
  done

  script_name="${0##*/}"
  script_name="${script_name%.sh}"
  printf '%s:%s:%s' "$script_name" "main" "0"
}

_log_timestamp() {
  date '+%Y-%m-%d %H:%M:%S%z'
}

_log_filesize() {
  local file="$1"
  stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0
}

_log_supports_color() {
  [[ "${FVTT_LOG_USE_COLOR}" == "true" ]] && [[ -t 2 ]]
}

rotate_logs() {
  local file="${1:-${LOG_FILE:-}}"
  [[ -n "${file}" && -f "${file}" ]] || return 0

  local size
  size="$(_log_filesize "$file")"

  if [[ "${size}" -ge "${FVTT_LOG_MAX_SIZE_BYTES}" ]]; then
    local rotated="${file}.$(date +%Y%m%d-%H%M%S)"
    mv -- "${file}" "${rotated}"
    : > "${file}"

    find "$(dirname "$file")" -maxdepth 1 -type f -name "$(basename "$file").*" -printf '%T@ %p\n' \
      | sort -nr \
      | awk "NR>${FVTT_LOG_KEEP_ROTATED} {print \$2}" \
      | xargs -r rm -f --
  fi
}

_log_write() {
  local level="$1"
  local color="$2"
  shift 2

  log_init

  local ts msg caller_context line
  ts="$(_log_timestamp)"
  msg="$*"
  caller_context="$(_get_caller_context)"
  line="[${ts}] [${level}] [${caller_context}] ${msg}"

  rotate_logs "${LOG_FILE}"
  printf '%s\n' "${line}" >> "${LOG_FILE}"

  if [[ "${FVTT_LOG_TO_STDERR}" == "true" ]]; then
    if _log_supports_color; then
      printf '%b%s%b\n' "${color}" "${line}" "${COLOR_RESET}" >&2
    else
      printf '%s\n' "${line}" >&2
    fi
  fi
}

log_debug() {
  [[ "${FVTT_VERBOSE_LOGGING}" == "true" ]] || return 0
  _log_write "DEBUG" "${COLOR_DEBUG}" "$@"
}

log_info()  { _log_write "INFO"  "${COLOR_INFO}" " $@"; }
log_warn()  { _log_write "WARN"  "${COLOR_WARN}" " $@"; }
log_error() { _log_write "ERROR" "${COLOR_ERROR}" "$@"; }
log_fatal() { _log_write "FATAL" "${COLOR_ERROR}" "$@"; }