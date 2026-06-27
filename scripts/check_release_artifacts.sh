#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}/.."

usage() {
  cat <<'EOF'
Usage:
  ./scripts/check_release_artifacts.sh [--platform all|mac|windows] [artifact-dir]

Validates Electron release artifacts produced by GitHub Actions or a local
electron-builder dist directory. The check is recursive, so it accepts either a
merged release-artifacts folder or separate downloaded artifact folders.

Defaults:
  --platform all
  artifact-dir desktop/electron/dist
EOF
}

MODE="all"
if (( $# > 0 )); then
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --platform)
      if (( $# < 2 )); then
        echo "Missing value after --platform." >&2
        usage >&2
        exit 2
      fi
      MODE="$2"
      shift 2
      ;;
    --platform=*)
      MODE="${1#--platform=}"
      shift
      ;;
  esac
fi

case "$MODE" in
  all|mac|windows)
    ;;
  *)
    echo "Unsupported platform mode: $MODE" >&2
    usage >&2
    exit 2
    ;;
esac

if (( $# > 1 )); then
  echo "Too many arguments." >&2
  usage >&2
  exit 2
fi

ARTIFACT_DIR="${1:-$ROOT/desktop/electron/dist}"

if [[ ! -d "$ARTIFACT_DIR" ]]; then
  echo "Artifact directory does not exist: $ARTIFACT_DIR" >&2
  exit 1
fi

ARTIFACT_DIR="${ARTIFACT_DIR:A}"
FAIL=0

find_matches() {
  local pattern="$1"
  find "$ARTIFACT_DIR" -type f -name "$pattern" -print | sort
}

require_any() {
  local label="$1"
  local pattern="$2"
  local matches=("${(@f)$(find_matches "$pattern")}")

  if (( ${#matches[@]} == 0 )); then
    echo "Missing $label ($pattern)" >&2
    FAIL=1
    return
  fi

  echo "$label:"
  printf "  %s\n" "${matches[@]}"
}

require_updater_yaml() {
  local label="$1"
  local filename="$2"
  local extension_pattern="$3"
  local matches=("${(@f)$(find_matches "$filename")}")

  if (( ${#matches[@]} == 0 )); then
    echo "Missing $label ($filename)" >&2
    FAIL=1
    return
  fi

  echo "$label:"
  for file in "${matches[@]}"; do
    echo "  $file"
    if [[ ! -s "$file" ]]; then
      echo "Updater metadata is empty: $file" >&2
      FAIL=1
      continue
    fi
    grep -q "^version:" "$file" || {
      echo "Updater metadata is missing version: $file" >&2
      FAIL=1
    }
    grep -q "^files:" "$file" || {
      echo "Updater metadata is missing files list: $file" >&2
      FAIL=1
    }
    grep -q "sha512:" "$file" || {
      echo "Updater metadata is missing sha512: $file" >&2
      FAIL=1
    }
    grep -Eq "$extension_pattern" "$file" || {
      echo "Updater metadata does not reference expected installer type: $file" >&2
      FAIL=1
    }
  done
}

echo "== release artifact directory =="
echo "$ARTIFACT_DIR"

if [[ "$MODE" == "all" || "$MODE" == "mac" ]]; then
  echo
  echo "== macOS artifacts =="
  require_any "macOS DMG" "*.dmg"
  require_any "macOS ZIP updater payload" "*.zip"
  require_any "macOS updater blockmap" "*.zip.blockmap"
  require_updater_yaml "macOS updater metadata" "latest-mac.yml" "\\.zip"
fi

if [[ "$MODE" == "all" || "$MODE" == "windows" ]]; then
  echo
  echo "== Windows artifacts =="
  require_any "Windows NSIS installer" "*.exe"
  require_any "Windows updater blockmap" "*.exe.blockmap"
  require_updater_yaml "Windows updater metadata" "latest.yml" "\\.exe"
fi

if (( FAIL != 0 )); then
  echo
  echo "release_artifacts_check_failed" >&2
  exit 1
fi

echo
echo "release_artifacts_ok"
