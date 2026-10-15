#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

. "$SCRIPT_DIR/load-env.sh"
load_project_env "$REPO_ROOT"

echo "=== Building addon package ==="
bash "$SCRIPT_DIR/build.sh"

echo "=== Deploying to GitHub ==="
perl "$SCRIPT_DIR/deploy-github.pl" "$@"

echo "=== Deploying to CurseForge ==="
perl "$SCRIPT_DIR/deploy-curseforge.pl" "$@"

echo "=== Deployment Complete ==="
