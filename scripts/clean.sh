#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
DIST_DIR="$REPO_ROOT/dist"

. "$SCRIPT_DIR/output-style.sh"

if [[ ! -e "$DIST_DIR" && ! -L "$DIST_DIR" ]]; then
  status_info "dist is already clean."
  exit 0
fi

if [[ -L "$DIST_DIR" || ! -d "$DIST_DIR" || "$(cd -- "$DIST_DIR" && pwd -P)" != "$DIST_DIR" ]]; then
  status_error "Error: dist must be a real directory inside the repository."
  exit 1
fi

status_info "Removing all contents of dist..."
find -P "$DIST_DIR" -mindepth 1 -depth -delete
status_success "dist is clean."
