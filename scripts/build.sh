#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

. "$SCRIPT_DIR/load-env.sh"
load_project_env "$REPO_ROOT"

require_project_config ADDON_NAME
require_project_config FOLDER_NAME
require_project_config TOC_FILE
require_project_config DIST_DIR
require_project_config ZIP_NAME
TARGET_DIR="${DIST_DIR}/${FOLDER_NAME}"
ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"

# 1. Git checkout the submodules
echo "Updating git submodules..."
if ! command -v git >/dev/null 2>&1; then
  echo "Error: git command not found." >&2
  exit 1
fi
git submodule update --init --recursive

# 2. Extract version from TOC file
if [[ ! -f "$TOC_FILE" ]]; then
  echo "Error: $TOC_FILE not found in $REPO_ROOT" >&2
  exit 1
fi

VERSION=$(grep -i '^[[:space:]]*##[[:space:]]*Version:' "$TOC_FILE" | head -n 1 | sed -E 's/^[[:space:]]*##[[:space:]]*[Vv]ersion:[[:space:]]*//' | tr -d '\r\n')
VERSION="$(echo "$VERSION" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [[ -z "$VERSION" ]]; then
  echo "Error: Could not extract version from $TOC_FILE" >&2
  exit 1
fi

echo "Building ${FOLDER_NAME} (version: ${VERSION})..."

# Create clean destination folder inside dist
mkdir -p "$DIST_DIR"
rm -rf "$TARGET_DIR"
rm -f "$ZIP_PATH"
mkdir -p "$TARGET_DIR"

# Helper functions for filtering files
is_hidden() {
  local p="${1#./}"
  [[ "$p" =~ (^|/)\.[^/]+ ]]
}

is_ace3_test() {
  local p="${1#./}"
  [[ "$p" =~ (^|/)Ace3/tests(/|$) ]]
}

copy_file() {
  local src="$1"
  local rel_dest="$2"
  local dest="${TARGET_DIR}/${rel_dest}"
  mkdir -p "$(dirname "$dest")"
  cp -p "$src" "$dest"
}

echo "Copying files into ${TARGET_DIR}..."

# 3. Copy files/folders recursively, skipping all dot (hidden) files:
#    - All .lua, .toc, .xml files (excluding dist, Libs, and Assets)
find . -type f \( -name "*.lua" -o -name "*.toc" -o -name "*.xml" \) | while IFS= read -r file; do
  rel="${file#./}"
  if is_hidden "$rel"; then
    continue
  fi
  if [[ "$rel" =~ ^(dist|Libs|Assets|scripts)/ ]]; then
    continue
  fi
  copy_file "$file" "$rel"
done

#    - All files in "Assets" dir
if [[ -d "Assets" ]]; then
  find Assets -type f | while IFS= read -r file; do
    rel="${file#./}"
    if is_hidden "$rel"; then
      continue
    fi
    copy_file "$file" "$rel"
  done
fi

#    - All files in "Libs" dir minus dot (hidden) files and the Ace3/tests dir
if [[ -d "Libs" ]]; then
  find Libs -type f | while IFS= read -r file; do
    rel="${file#./}"
    if is_hidden "$rel"; then
      continue
    fi
    if is_ace3_test "$rel"; then
      continue
    fi
    copy_file "$file" "$rel"
  done
fi

# 4. Compress created folder into a zip named after the versioned addon inside dist
echo "Compressing ${TARGET_DIR} into ${ZIP_PATH}..."

(
  cd "$DIST_DIR"
  if command -v zip >/dev/null 2>&1; then
    zip -r -q "$ZIP_NAME" "$FOLDER_NAME"
  elif [[ -x "/c/Windows/System32/tar.exe" ]]; then
    /c/Windows/System32/tar.exe -a -cf "$ZIP_NAME" "$FOLDER_NAME"
  elif command -v bsdtar >/dev/null 2>&1; then
    bsdtar -a -cf "$ZIP_NAME" "$FOLDER_NAME"
  elif command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command "Compress-Archive -Path '$FOLDER_NAME' -DestinationPath '$ZIP_NAME' -Force"
  elif [[ -x "/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" ]]; then
    /c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -Command "Compress-Archive -Path '$FOLDER_NAME' -DestinationPath '$ZIP_NAME' -Force"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -m zipfile -c "$ZIP_NAME" "$FOLDER_NAME"
  elif command -v python >/dev/null 2>&1; then
    python -m zipfile -c "$ZIP_NAME" "$FOLDER_NAME"
  elif command -v 7z >/dev/null 2>&1; then
    7z a "$ZIP_NAME" "$FOLDER_NAME" >/dev/null
  else
    echo "Error: No suitable compression tool found (tried zip, bsdtar, powershell, python, 7z)." >&2
    exit 1
  fi
)

echo "Build succeeded: ${ZIP_PATH}"
