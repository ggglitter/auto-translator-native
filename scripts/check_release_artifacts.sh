#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}/.."

usage() {
  cat <<'EOF'
Usage:
  ./scripts/check_release_artifacts.sh [--platform all|mac|windows] [--mac-arch any|arm64|x64|universal] [artifact-dir]

Validates Electron release artifacts produced by GitHub Actions or a local
electron-builder dist directory. The check is recursive, so it accepts either a
merged release-artifacts folder or separate downloaded artifact folders.

Defaults:
  --platform all
  --mac-arch any
  artifact-dir desktop/electron/dist
EOF
}

MODE="all"
MAC_ARCH="any"
ARTIFACT_DIR=""

while (( $# > 0 )); do
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

case "$MODE" in
  all|mac|windows)
    ;;
  *)
    echo "Unsupported platform mode: $MODE" >&2
    usage >&2
    exit 2
    ;;
esac

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
FAIL=0

find_matches() {
  local pattern="$1"
  find "$ARTIFACT_DIR" -type f -name "$pattern" -print | sort
}

require_any() {
  local label="$1"
  local pattern="$2"
  local raw_matches
  local matches=()

  raw_matches="$(find_matches "$pattern")"
  if [[ -n "$raw_matches" ]]; then
    matches=("${(@f)raw_matches}")
  fi

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
  local raw_matches
  local matches=()

  raw_matches="$(find_matches "$filename")"
  if [[ -n "$raw_matches" ]]; then
    matches=("${(@f)raw_matches}")
  fi

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
    if ! /usr/bin/python3 - "$file" <<'PY'
import base64
import hashlib
import re
import sys
from pathlib import Path

yaml_path = Path(sys.argv[1])
lines = yaml_path.read_text(encoding="utf-8").splitlines()
entries = []
current = None
in_files = False

for line in lines:
    if re.match(r"^files:\s*$", line):
        in_files = True
        continue
    if in_files and line and not line.startswith((" ", "\t", "-")):
        in_files = False
        current = None
    if not in_files:
        continue

    url_match = re.match(r"^\s*-\s+url:\s*(.+?)\s*$", line)
    if url_match:
        current = {"url": url_match.group(1).strip("'\"")}
        entries.append(current)
        continue

    if current is None:
        continue

    sha_match = re.match(r"^\s+sha512:\s*(.+?)\s*$", line)
    if sha_match:
        current["sha512"] = sha_match.group(1).strip("'\"")
        continue

    size_match = re.match(r"^\s+size:\s*([0-9]+)\s*$", line)
    if size_match:
        current["size"] = int(size_match.group(1))

if not entries:
    raise SystemExit(f"Updater metadata has no files entries: {yaml_path}")

ok = True
for entry in entries:
    missing = [key for key in ("url", "sha512", "size") if key not in entry]
    if missing:
        print(f"Updater metadata file entry is missing {', '.join(missing)}: {yaml_path}", file=sys.stderr)
        ok = False
        continue

    payload = yaml_path.parent / entry["url"]
    if not payload.is_file():
        print(f"Updater metadata references missing payload: {yaml_path} -> {entry['url']}", file=sys.stderr)
        ok = False
        continue

    data = payload.read_bytes()
    actual_size = len(data)
    if actual_size != entry["size"]:
        print(
            f"Updater metadata size mismatch for {payload}: expected {entry['size']}, got {actual_size}",
            file=sys.stderr,
        )
        ok = False

    actual_sha512 = base64.b64encode(hashlib.sha512(data).digest()).decode("ascii")
    if actual_sha512 != entry["sha512"]:
        print(f"Updater metadata sha512 mismatch for {payload}", file=sys.stderr)
        ok = False

    if actual_size == entry["size"] and actual_sha512 == entry["sha512"]:
        print(f"updater_payload_ok {payload}")

if not ok:
    raise SystemExit(1)
PY
    then
      FAIL=1
    fi
  done
}

echo "== release artifact directory =="
echo "$ARTIFACT_DIR"
echo "mac_arch_requirement=$MAC_ARCH"

if [[ "$MODE" == "all" || "$MODE" == "mac" ]]; then
  echo
  echo "== macOS artifacts =="
  if [[ "$MAC_ARCH" == "any" ]]; then
    MAC_DMG_PATTERN="*.dmg"
    MAC_ZIP_PATTERN="*.zip"
    MAC_BLOCKMAP_PATTERN="*.zip.blockmap"
    MAC_YAML_REFERENCE_PATTERN="\\.zip"
  else
    MAC_DMG_PATTERN="*${MAC_ARCH}*.dmg"
    MAC_ZIP_PATTERN="*${MAC_ARCH}*.zip"
    MAC_BLOCKMAP_PATTERN="*${MAC_ARCH}*.zip.blockmap"
    MAC_YAML_REFERENCE_PATTERN="${MAC_ARCH}.*\\.zip|\\.zip.*${MAC_ARCH}"
  fi
  require_any "macOS DMG" "$MAC_DMG_PATTERN"
  require_any "macOS ZIP updater payload" "$MAC_ZIP_PATTERN"
  require_any "macOS updater blockmap" "$MAC_BLOCKMAP_PATTERN"
  require_updater_yaml "macOS updater metadata" "latest-mac.yml" "$MAC_YAML_REFERENCE_PATTERN"
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
