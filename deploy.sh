#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Deploying to GitHub ==="
perl "$SCRIPT_DIR/deploy-github.pl" "$@"

echo "=== Deploying to CurseForge ==="
perl "$SCRIPT_DIR/deploy-curseforge.pl" "$@"

echo "=== Deployment Complete ==="
