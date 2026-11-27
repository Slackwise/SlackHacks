#!/usr/bin/env bash
set -u

repo_path=""
rerun=false

# The updater re-executes a temporary copy while the repository is being replaced,
# so its status formatter must not depend on files in the working tree.
script_status() {
  local level="$1" color="$2" message="$3"
  if [[ -t 2 && -z "${NO_COLOR+x}" && "${TERM:-}" != dumb ]]; then
    printf '\033[%sm[%s] %s\033[0m\n' "$color" "$level" "$message" >&2
  else
    printf '%s\n' "$message" >&2
  fi
}
status_info() { script_status INFO 36 "$1"; }
status_success() { script_status OK 32 "$1"; }
status_warning() { script_status WARN 33 "$1"; }
status_error() { script_status ERROR 31 "$1"; }

usage() {
  echo "Usage: $(basename "$0") [--repo-path PATH] [--rerun]" >&2
}

show_error() {
  status_error "Error: $1"
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
    status_warning "Git was not found. Attempting to install it for this Linux system..."
    install_git
    status_success "Git installation completed successfully."
  else
    status_info "Git is already installed."
  fi
}

invoke_git_wipe() {
  local path="$1"

  # Discard any local modifications/untracked files before pulling so the update always applies cleanly.
  status_info "Discarding local changes for '$path'..."
  git -C "$path" reset --hard HEAD
  if [[ $? -ne 0 ]]; then
    fail_and_pause "Failed to discard local changes for '$path'. Please resolve any git issues and try again."
  fi

  git -C "$path" clean -fdx -e dist/SlackHacks_MediaMetadata/
  if [[ $? -ne 0 ]]; then
    fail_and_pause "Failed to remove untracked files for '$path'. Please resolve any git issues and try again."
  fi

  # Submodule working trees (e.g. Libs/Ace3) aren't touched by the superproject's own reset/clean.
  git -C "$path" submodule foreach --recursive git reset --hard HEAD
  if [[ $? -ne 0 ]]; then
    fail_and_pause "Failed to discard local changes in submodules for '$path'. Please resolve any git issues and try again."
  fi

  git -C "$path" submodule foreach --recursive git clean -fdx
  if [[ $? -ne 0 ]]; then
    fail_and_pause "Failed to remove untracked files in submodules for '$path'. Please resolve any git issues and try again."
  fi
  status_success "Local changes discarded successfully."
}

invoke_git_pull() {
  local path="$1"

  status_info "Starting git pull for '$path'..."
  git -C "$path" pull --force --ff-only
  if [[ $? -ne 0 ]]; then
    fail_and_pause "Failed to pull the latest changes for '$path'. Please resolve any git issues and try again."
  fi
  status_success "Git pull completed successfully."

  status_info "Updating submodules for '$path'..."
  git -C "$path" submodule update --init --recursive --force
  if [[ $? -ne 0 ]]; then
    fail_and_pause "Failed to update submodules for '$path'. Please resolve any git issues and try again."
  fi
  status_success "Submodule update completed successfully."
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
  status_info "No repo path provided. Re-running the script from the current addon directory..."
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
  temp_script="$(mktemp "${TMPDIR:-/tmp}/$(basename "$0").XXXXXX")"
  cp "$0" "$temp_script"
  chmod +x "$temp_script"
  "$temp_script" --repo-path "$script_dir"
  exit $? 
fi

if [[ ! -d "$repo_path" ]]; then
  fail_and_pause "Repository path does not exist: $repo_path"
fi

status_info "Starting SlackHacks update for '$repo_path'..."
cd "$repo_path" || {
  fail_and_pause "Unable to access repository path: $repo_path"
}

assert_git_installed
invoke_git_wipe "$repo_path"
invoke_git_pull "$repo_path"

script_name="scripts/update-addon.sh"
pulled_script="$repo_path/$script_name"
if [[ -f "$pulled_script" ]]; then
  # git doesn't preserve the executable bit reliably across pulls on all platforms.
  chmod +x "$pulled_script"
fi

if [[ "$rerun" != true && -f "$pulled_script" ]]; then
  status_info "Checking whether a newer version of this updater script is available..."
  running_hash="$(sha256sum "$0" | awk '{print $1}')"
  pulled_hash="$(sha256sum "$pulled_script" | awk '{print $1}')"

  if [[ "$running_hash" != "$pulled_hash" ]]; then
    status_info "A newer version of the updater was found. Re-running with the updated script..."
    temp_script="$(mktemp "${TMPDIR:-/tmp}/update-addon.XXXXXX")"
    cp "$pulled_script" "$temp_script"
    chmod +x "$temp_script"
    "$temp_script" --repo-path "$repo_path" --rerun
    exit $? 
  fi
fi

status_info "Building SlackHacks: Media Metadata..."
if ! command -v perl >/dev/null 2>&1; then
  fail_and_pause "Perl is required to build SlackHacks: Media Metadata. Install Perl and retry."
fi
if ! perl "$repo_path/scripts/package-media-metadata.pl"; then
  fail_and_pause "Failed to build SlackHacks: Media Metadata."
fi

status_success "SlackHacks update completed successfully."
pause_for_exit
