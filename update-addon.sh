#!/usr/bin/env bash
set -u

repo_path=""
rerun=false

usage() {
  echo "Usage: $(basename "$0") [--repo-path PATH] [--rerun]" >&2
}

show_error() {
  echo "Error: $1" >&2
}

pause_for_exit() {
  printf '\nPress the space bar to exit... '
  local key=""
  while true; do
    IFS= read -rsn1 key || {
      echo
      return
    }
    if [[ "$key" == " " || "$key" == $'\n' || "$key" == $'\r' ]]; then
      echo
      return
    fi
  done
}

fail_and_pause() {
  local message="$1"
  show_error "$message"
  pause_for_exit
  exit 1
}

install_git() {
  local os_name=""
  local sudo_cmd=""

  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    os_name="${ID:-}"
  fi

  if [[ $(id -u) -eq 0 ]]; then
    sudo_cmd=""
  elif command -v sudo >/dev/null 2>&1; then
    sudo_cmd="sudo"
  else
    fail_and_pause "Git is required, and sudo is not available. Please install Git manually and try again."
  fi

  case "$os_name" in
    ubuntu|debian|linuxmint|pop)
      if [[ -n "$sudo_cmd" ]]; then
        $sudo_cmd apt-get update && $sudo_cmd apt-get install -y git
      else
        apt-get update && apt-get install -y git
      fi
      ;;
    fedora|rhel|centos|rocky|almalinux)
      if command -v dnf >/dev/null 2>&1; then
        if [[ -n "$sudo_cmd" ]]; then
          $sudo_cmd dnf install -y git
        else
          dnf install -y git
        fi
      else
        if [[ -n "$sudo_cmd" ]]; then
          $sudo_cmd yum install -y git
        else
          yum install -y git
        fi
      fi
      ;;
    arch|manjaro)
      if [[ -n "$sudo_cmd" ]]; then
        $sudo_cmd pacman -Sy --noconfirm git
      else
        pacman -Sy --noconfirm git
      fi
      ;;
    opensuse*|sles)
      if [[ -n "$sudo_cmd" ]]; then
        $sudo_cmd zypper install -y git
      else
        zypper install -y git
      fi
      ;;
    alpine)
      if [[ -n "$sudo_cmd" ]]; then
        $sudo_cmd apk add --no-cache git
      else
        apk add --no-cache git
      fi
      ;;
    *)
      fail_and_pause "Unsupported Linux distribution for automatic Git installation. Please install Git manually and try again."
      ;;
  esac

  if ! command -v git >/dev/null 2>&1; then
    fail_and_pause "Git installation was attempted but the command is still unavailable. Please install Git manually and try again."
  fi
}

assert_git_installed() {
  if ! command -v git >/dev/null 2>&1; then
    echo "Git was not found. Attempting to install it for this Linux system..." >&2
    install_git
    echo "Git installation completed successfully." >&2
  else
    echo "Git is already installed." >&2
  fi
}

invoke_git_pull() {
  local path="$1"

  echo "Starting git pull for '$path'..." >&2
  git -C "$path" pull --ff-only
  if [[ $? -ne 0 ]]; then
    fail_and_pause "Failed to pull the latest changes for '$path'. Please resolve any git issues and try again."
  fi
  echo "Git pull completed successfully." >&2

  echo "Updating submodules for '$path'..." >&2
  git -C "$path" submodule update --init --recursive --force
  if [[ $? -ne 0 ]]; then
    fail_and_pause "Failed to update submodules for '$path'. Please resolve any git issues and try again."
  fi
  echo "Submodule update completed successfully." >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-path)
      if [[ $# -lt 2 ]]; then
        fail_and_pause "Missing value for --repo-path"
      fi
      repo_path="$2"
      shift 2
      ;;
    --rerun|-r)
      rerun=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail_and_pause "Unknown argument: $1"
      ;;
  esac
done

if [[ -z "$repo_path" ]]; then
  echo "No repo path provided. Re-running the script from the current addon directory..." >&2
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  temp_script="$(mktemp "${TMPDIR:-/tmp}/$(basename "$0").XXXXXX")"
  cp "$0" "$temp_script"
  chmod +x "$temp_script"
  "$temp_script" --repo-path "$script_dir"
  exit $? 
fi

if [[ ! -d "$repo_path" ]]; then
  fail_and_pause "Repository path does not exist: $repo_path"
fi

echo "Starting SlackHacks update for '$repo_path'..." >&2
cd "$repo_path" || {
  fail_and_pause "Unable to access repository path: $repo_path"
}

assert_git_installed
invoke_git_pull "$repo_path"

script_name="$(basename "$0")"
pulled_script="$repo_path/$script_name"
if [[ "$rerun" != true && -f "$pulled_script" ]]; then
  echo "Checking whether a newer version of this updater script is available..." >&2
  running_hash="$(sha256sum "$0" | awk '{print $1}')"
  pulled_hash="$(sha256sum "$pulled_script" | awk '{print $1}')"

  if [[ "$running_hash" != "$pulled_hash" ]]; then
    echo "A newer version of the updater was found. Re-running with the updated script..." >&2
    temp_script="$(mktemp "${TMPDIR:-/tmp}/${script_name}.XXXXXX")"
    cp "$pulled_script" "$temp_script"
    chmod +x "$temp_script"
    "$temp_script" --repo-path "$repo_path" --rerun
    exit $? 
  fi
fi

echo "SlackHacks update completed successfully." >&2
pause_for_exit
