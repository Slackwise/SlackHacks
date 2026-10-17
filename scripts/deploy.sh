#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

. "$SCRIPT_DIR/load-env.sh"
load_project_env "$REPO_ROOT"

echo "=== Deploying to GitHub ==="
pwsh -NoProfile -File "$SCRIPT_DIR/Publish-GitHubRelease.ps1" "$@"

echo "=== Deploying to CurseForge ==="
pwsh -NoProfile -File "$SCRIPT_DIR/Publish-CurseForgeRelease.ps1" "$@"

echo "=== Deployment Complete ==="
