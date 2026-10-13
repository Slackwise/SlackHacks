#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# deploy-curseforge.sh
# 
# Deploys the built SlackHacks addon package to CurseForge using the Upload API.
#
# Prerequisites:
# 1. Proton Pass CLI (pass-cli) installed and authenticated.
# 2. CurseForge API token stored in Proton Pass.
# ==============================================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ------------------------------------------------------------------------------
# Configurable Variables & Settings (Please confirm / adjust as needed)
# ------------------------------------------------------------------------------
# CurseForge numeric Project ID for SlackHacks.
# You can find this on your project page on CurseForge (e.g., in the right sidebar).
CURSEFORGE_PROJECT_ID="${CURSEFORGE_PROJECT_ID:-"REPLACE_WITH_CURSEFORGE_PROJECT_ID"}"

# Release type: "release", "beta", or "alpha"
RELEASE_TYPE="${RELEASE_TYPE:-"release"}"

# Changelog format: "markdown", "text", or "html"
CHANGELOG_TYPE="${CHANGELOG_TYPE:-"markdown"}"

# Optional path to a changelog file. If not set or empty, will use git log or a default note.
CHANGELOG_FILE="${CHANGELOG_FILE:-""}"

# Game Version IDs required by CurseForge API (array of integers, e.g. "11394,11395").
# If left empty, the script will prompt or can fetch available game versions from CurseForge.
CURSEFORGE_GAME_VERSION_IDS="${CURSEFORGE_GAME_VERSION_IDS:-""}"

# Proton Pass CLI settings for retrieving the CurseForge API token:
# Item title/name in your Proton Pass vault
PROTON_PASS_ITEM="${PROTON_PASS_ITEM:-"CurseForge API Token"}"
# Vault name (leave empty if using the default vault)
PROTON_PASS_VAULT="${PROTON_PASS_VAULT:-""}"
# Attribute to retrieve (e.g., "password" or a custom field name)
PROTON_PASS_ATTRIBUTE="${PROTON_PASS_ATTRIBUTE:-"password"}"
# Binary name or path for Proton Pass CLI
PROTON_PASS_CLI_BIN="${PROTON_PASS_CLI_BIN:-"pass-cli"}"

# ------------------------------------------------------------------------------
# Helper: Fetch secret from Proton Pass CLI
# ------------------------------------------------------------------------------
fetch_secret_from_proton_pass() {
  local item="$1"
  local vault="$2"
  local attr="$3"

  # Allow environment variable override if already set
  if [[ -n "${CURSEFORGE_API_TOKEN:-}" ]]; then
    echo "$CURSEFORGE_API_TOKEN"
    return 0
  fi

  if ! command -v "$PROTON_PASS_CLI_BIN" >/dev/null 2>&1; then
    echo "Error: Proton Pass CLI ('$PROTON_PASS_CLI_BIN') was not found in PATH." >&2
    echo "Please ensure the Proton Pass CLI is installed and in your PATH, or set CURSEFORGE_API_TOKEN directly." >&2
    return 1
  fi

  local secret=""
  if [[ -n "$vault" ]]; then
    secret=$("$PROTON_PASS_CLI_BIN" item get "$item" --vault "$vault" --attribute "$attr" 2>/dev/null || true)
  else
    secret=$("$PROTON_PASS_CLI_BIN" item get "$item" --attribute "$attr" 2>/dev/null || true)
  fi

  # Clean whitespace and carriage returns
  secret="$(echo "$secret" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

  if [[ -z "$secret" ]]; then
    echo "Error: Could not retrieve secret for item '$item' from Proton Pass." >&2
    echo "Command attempted: $PROTON_PASS_CLI_BIN item get \"$item\" ${vault:+--vault \"$vault\"} --attribute \"$attr\"" >&2
    return 1
  fi

  echo "$secret"
}

# ------------------------------------------------------------------------------
# Step 1: Ensure build output is ready
# ------------------------------------------------------------------------------
TOC_FILE="SlackHacks.toc"
if [[ ! -f "$TOC_FILE" ]]; then
  echo "Error: $TOC_FILE not found in $SCRIPT_DIR" >&2
  exit 1
fi

VERSION=$(grep -i '^[[:space:]]*##[[:space:]]*Version:' "$TOC_FILE" | head -n 1 | sed -E 's/^[[:space:]]*##[[:space:]]*[Vv]ersion:[[:space:]]*//' | tr -d '\r\n')
VERSION="$(echo "$VERSION" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [[ -z "$VERSION" ]]; then
  echo "Error: Could not determine version from $TOC_FILE." >&2
  exit 1
fi

FOLDER_NAME="SlackHacks-v${VERSION#v}"
ZIP_PATH="dist/${FOLDER_NAME}.zip"

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Zip archive $ZIP_PATH not found. Running build.sh first..."
  bash ./build.sh
fi

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Error: Build output $ZIP_PATH is still missing after running build.sh." >&2
  exit 1
fi

echo "Found release archive: $ZIP_PATH"

# ------------------------------------------------------------------------------
# Step 2: Validate CurseForge Project ID
# ------------------------------------------------------------------------------
if [[ "$CURSEFORGE_PROJECT_ID" == "REPLACE_WITH_CURSEFORGE_PROJECT_ID" || -z "$CURSEFORGE_PROJECT_ID" ]]; then
  echo "Error: CURSEFORGE_PROJECT_ID is not configured." >&2
  echo "Please set CURSEFORGE_PROJECT_ID in this script or export it as an environment variable." >&2
  exit 1
fi

# ------------------------------------------------------------------------------
# Step 3: Retrieve API Token from Proton Pass
# ------------------------------------------------------------------------------
echo "Fetching CurseForge API Token from Proton Pass..."
API_TOKEN="$(fetch_secret_from_proton_pass "$PROTON_PASS_ITEM" "$PROTON_PASS_VAULT" "$PROTON_PASS_ATTRIBUTE")"
if [[ -z "$API_TOKEN" ]]; then
  exit 1
fi
echo "Successfully retrieved CurseForge API Token."

# ------------------------------------------------------------------------------
# Step 4: Resolve Game Versions
# ------------------------------------------------------------------------------
# CurseForge upload API expects an array of integer game version IDs.
# If CURSEFORGE_GAME_VERSION_IDS is provided (e.g. "1234,5678"), parse it.
GAME_VERSIONS_JSON="[]"
if [[ -n "$CURSEFORGE_GAME_VERSION_IDS" ]]; then
  # Format comma-separated IDs into JSON array: [123, 456]
  IFS=',' read -ra ID_LIST <<< "$CURSEFORGE_GAME_VERSION_IDS"
  FORMATTED_IDS=""
  for id in "${ID_LIST[@]}"; do
    clean_id="$(echo "$id" | tr -d '[:space:]')"
    if [[ -n "$clean_id" ]]; then
      if [[ -n "$FORMATTED_IDS" ]]; then
        FORMATTED_IDS="${FORMATTED_IDS}, ${clean_id}"
      else
        FORMATTED_IDS="${clean_id}"
      fi
    fi
  done
  GAME_VERSIONS_JSON="[${FORMATTED_IDS}]"
else
  echo "Note: CURSEFORGE_GAME_VERSION_IDS is empty."
  echo "You can query https://wow.curseforge.com/api/game/versions with your API token to look up IDs."
fi

# ------------------------------------------------------------------------------
# Step 5: Prepare Changelog
# ------------------------------------------------------------------------------
CHANGELOG_TEXT=""
if [[ -n "$CHANGELOG_FILE" && -f "$CHANGELOG_FILE" ]]; then
  CHANGELOG_TEXT="$(cat "$CHANGELOG_FILE")"
elif command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  LAST_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
  if [[ -n "$LAST_TAG" ]]; then
    CHANGELOG_TEXT="$(git log "${LAST_TAG}..HEAD" --oneline --no-merges 2>/dev/null || true)"
  else
    CHANGELOG_TEXT="$(git log -n 10 --oneline --no-merges 2>/dev/null || true)"
  fi
fi

if [[ -z "$CHANGELOG_TEXT" ]]; then
  CHANGELOG_TEXT="Release ${FOLDER_NAME}"
fi

# ------------------------------------------------------------------------------
# Step 6: Construct Metadata JSON and Upload
# ------------------------------------------------------------------------------
# Escape JSON strings
escape_json() {
  local str="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json, sys; print(json.dumps(sys.stdin.read())[1:-1], end="")' <<< "$str"
  elif command -v python >/dev/null 2>&1; then
    python -c 'import json, sys; print(json.dumps(sys.stdin.read())[1:-1], end="")' <<< "$str"
  else
    # Basic fallback escaping
    echo "$str" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//'
  fi
}

ESCAPED_CHANGELOG="$(escape_json "$CHANGELOG_TEXT")"
DISPLAY_NAME="${FOLDER_NAME}"

METADATA_JSON=$(cat <<EOF
{
  "changelog": "${ESCAPED_CHANGELOG}",
  "changelogType": "${CHANGELOG_TYPE}",
  "displayName": "${DISPLAY_NAME}",
  "parentFileID": null,
  "gameVersions": ${GAME_VERSIONS_JSON},
  "releaseType": "${RELEASE_TYPE}"
}
EOF
)

UPLOAD_URL="https://wow.curseforge.com/api/projects/${CURSEFORGE_PROJECT_ID}/upload-file"

echo "=== CurseForge Deployment Summary ==="
echo "Project ID:    ${CURSEFORGE_PROJECT_ID}"
echo "Display Name:  ${DISPLAY_NAME}"
echo "Release Type:  ${RELEASE_TYPE}"
echo "Archive:       ${ZIP_PATH}"
echo "Upload URL:    ${UPLOAD_URL}"
echo "Game Versions: ${GAME_VERSIONS_JSON}"
echo "======================================"

# Perform upload via curl
echo "Uploading to CurseForge..."
RESPONSE=$(curl -s -S -w "\nHTTP_STATUS:%{http_code}" \
  -H "X-Api-Token: ${API_TOKEN}" \
  -F "metadata=${METADATA_JSON}" \
  -F "file=@${ZIP_PATH}" \
  "${UPLOAD_URL}")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)
BODY=$(echo "$RESPONSE" | sed -e '/HTTP_STATUS:/d')

if [[ "$HTTP_STATUS" -ge 200 && "$HTTP_STATUS" -lt 300 ]]; then
  echo "Deployment to CurseForge succeeded (HTTP $HTTP_STATUS)!"
  echo "Response: $BODY"
else
  echo "Error: CurseForge deployment failed with HTTP status $HTTP_STATUS." >&2
  echo "Response: $BODY" >&2
  exit 1
fi
