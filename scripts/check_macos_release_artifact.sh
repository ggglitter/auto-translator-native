#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}/.."

usage() {
  cat <<'EOF'
Usage:
  ./scripts/check_macos_release_artifact.sh [--mac-arch any|arm64|x64|universal] [artifact-dir]

Deep-checks macOS Electron release artifacts:

- required DMG/ZIP/update metadata shape
- DMG checksum validity with hdiutil verify
- ZIP extraction
- contained .app strict code-signature verification
- contained app executable architecture

Defaults:
  --mac-arch any
  artifact-dir desktop/electron/dist
EOF
}

MAC_ARCH="any"
ARTIFACT_DIR=""

while (( $# > 0 )); do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --mac-arch)
      if (( $# < 2 )); then
        echo "Missing value after --mac-arch." >&2
        usage >&2
        exit 2
      fi
      MAC_ARCH="$2"
      shift 2
      ;;
    --mac-arch=*)
      MAC_ARCH="${1#--mac-arch=}"
      shift
      ;;
    --*)
      echo "Unsupported option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [[ -n "$ARTIFACT_DIR" ]]; then
        echo "Too many artifact directories." >&2
        usage >&2
        exit 2
      fi
      ARTIFACT_DIR="$1"
      shift
      ;;
  esac
done

case "$MAC_ARCH" in
  any|arm64|x64|universal)
    ;;
  *)
    echo "Unsupported mac arch: $MAC_ARCH" >&2
    usage >&2
    exit 2
    ;;
esac

ARTIFACT_DIR="${ARTIFACT_DIR:-$ROOT/desktop/electron/dist}"

if [[ ! -d "$ARTIFACT_DIR" ]]; then
  echo "Artifact directory does not exist: $ARTIFACT_DIR" >&2
  exit 1
fi

ARTIFACT_DIR="${ARTIFACT_DIR:A}"

find_one() {
  local label="$1"
  local pattern="$2"
  local matches=("${(@f)$(find "$ARTIFACT_DIR" -type f -name "$pattern" -print | sort)}")

  if (( ${#matches[@]} == 0 )); then
    echo "Missing $label ($pattern)" >&2
    exit 1
  fi
  if (( ${#matches[@]} > 1 )); then
    echo "Expected one $label but found ${#matches[@]} ($pattern):" >&2
    printf "  %s\n" "${matches[@]}" >&2
    exit 1
  fi

  print -r -- "${matches[1]}"
}

case "$MAC_ARCH" in
  any)
    DMG_PATTERN="*.dmg"
    ZIP_PATTERN="*.zip"
    ;;
  *)
    DMG_PATTERN="*${MAC_ARCH}*.dmg"
    ZIP_PATTERN="*${MAC_ARCH}*.zip"
    ;;
esac

echo "== macOS release artifact directory =="
echo "$ARTIFACT_DIR"
echo "mac_arch_requirement=$MAC_ARCH"

echo
echo "== macOS artifact shape =="
"$ROOT/scripts/check_release_artifacts.sh" --platform mac --mac-arch "$MAC_ARCH" "$ARTIFACT_DIR"

DMG_PATH="$(find_one "macOS DMG" "$DMG_PATTERN")"
ZIP_PATH="$(find_one "macOS ZIP updater payload" "$ZIP_PATTERN")"

echo
echo "== macOS DMG verify =="
hdiutil verify "$DMG_PATH"
echo "macos_dmg_verify_ok"

TMP_DIR="$(mktemp -d /tmp/autotranslator-macos-artifact-check.XXXXXX)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo
echo "== macOS ZIP extract =="
ditto -x -k "$ZIP_PATH" "$TMP_DIR"
echo "macos_zip_extract_ok $TMP_DIR"

APP_MATCHES=("${(@f)$(find "$TMP_DIR" -maxdepth 2 -type d -name "*.app" -print | sort)}")
if (( ${#APP_MATCHES[@]} == 0 )); then
  echo "No .app found after extracting $ZIP_PATH" >&2
  exit 1
fi
if (( ${#APP_MATCHES[@]} > 1 )); then
  echo "Expected one top-level .app after ZIP extraction but found ${#APP_MATCHES[@]}:" >&2
  printf "  %s\n" "${APP_MATCHES[@]}" >&2
  exit 1
fi
APP_PATH="${APP_MATCHES[1]}"
echo "$APP_PATH"

echo
echo "== macOS ZIP app signature =="
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
echo "macos_zip_codesign_strict_ok"

echo
echo "== macOS ZIP app architecture =="
EXECUTABLE_NAME="$(
  /usr/bin/python3 - "$APP_PATH" <<'PY'
import plistlib
import sys
from pathlib import Path

app = Path(sys.argv[1])
plist = plistlib.loads((app / "Contents/Info.plist").read_bytes())
executable = plist.get("CFBundleExecutable")
if not executable:
    raise SystemExit("CFBundleExecutable missing from app Info.plist")
print(executable)
PY
)"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "App executable missing or not executable: $EXECUTABLE_PATH" >&2
  exit 1
fi

ARCHES="$(lipo -archs "$EXECUTABLE_PATH")"
echo "$ARCHES"

case "$MAC_ARCH" in
  any)
    [[ -n "$ARCHES" ]] || {
      echo "No architectures reported for app executable." >&2
      exit 1
    }
    ;;
  arm64)
    [[ " $ARCHES " == *" arm64 "* ]] || {
      echo "Expected arm64 executable architecture." >&2
      exit 1
    }
    ;;
  x64)
    [[ " $ARCHES " == *" x86_64 "* ]] || {
      echo "Expected x86_64 executable architecture." >&2
      exit 1
    }
    ;;
  universal)
    [[ " $ARCHES " == *" arm64 "* && " $ARCHES " == *" x86_64 "* ]] || {
      echo "Expected universal executable architectures: arm64 and x86_64." >&2
      exit 1
    }
    ;;
esac
echo "macos_zip_architecture_ok"

echo
echo "macos_release_artifact_ok"
