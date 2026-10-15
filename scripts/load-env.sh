#!/usr/bin/env bash

load_project_env() {
  local repo_root="$1"
  local caller_env
  local caller_allexport=0

  if [[ ! -f "$repo_root/scripts/defaults.env" ]]; then
    echo "Error: Missing scripts/defaults.env. Restore the project defaults file." >&2
    return 1
  fi

  caller_env="$(export -p)"
  if [[ $- == *a* ]]; then
    caller_allexport=1
  fi
  set -a
  if [[ -f "$repo_root/scripts/defaults.env" ]]; then
    source "$repo_root/scripts/defaults.env"
  fi
  if [[ -f "$repo_root/.env" ]]; then
    source "$repo_root/.env"
  fi
  if (( ! caller_allexport )); then
    set +a
  fi
  eval "$caller_env"
}

require_project_config() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Error: Required setting $name is missing. Check scripts/defaults.env." >&2
    return 1
  fi
}
