#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

if [[ -f "$REPO_ROOT/.env" ]]; then
  set -a
  source "$REPO_ROOT/.env"
  set +a
fi

echo "=== Deploying to GitHub ==="
perl "$SCRIPT_DIR/deploy-github.pl" "$@"

echo "=== Deploying to CurseForge ==="
perl "$SCRIPT_DIR/deploy-curseforge.pl" "$@"

echo "=== Deployment Complete ==="
