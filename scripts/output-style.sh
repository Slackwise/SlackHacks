#!/usr/bin/env bash

# Preserve plain output for pipes, logs, NO_COLOR, and terminals without color support.
script_status() {
  local level="$1" color="$2" message="$3" fd="${4:-1}"
  if [[ -t "$fd" && -z "${NO_COLOR+x}" && "${TERM:-}" != dumb ]]; then
    printf '\033[%sm[%s] %s\033[0m\n' "$color" "$level" "$message" >&"$fd"
  else
    printf '%s\n' "$message" >&"$fd"
  fi
}
status_info() { script_status INFO 36 "$1" "${2:-1}"; }
status_success() { script_status OK 32 "$1" "${2:-1}"; }
status_warning() { script_status WARN 33 "$1" "${2:-2}"; }
status_error() { script_status ERROR 31 "$1" "${2:-2}"; }
