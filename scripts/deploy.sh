#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

. "$SCRIPT_DIR/load-env.sh"
. "$SCRIPT_DIR/output-style.sh"
load_project_env "$REPO_ROOT"

status_info "=== Deploying to GitHub ==="
perl "$SCRIPT_DIR/deploy-github.pl" "$@"

status_info "=== Deploying to CurseForge ==="
perl "$SCRIPT_DIR/deploy-curseforge.pl" "$@"

status_success "=== Deployment Complete ==="
