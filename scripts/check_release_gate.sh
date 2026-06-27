#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}/.."

usage() {
  cat <<'EOF'
Usage:
  ./scripts/check_release_gate.sh [--allow-dirty]

Final local gate before pushing main and a release tag. By default this requires
a clean tracked/untracked source tree, matching app versions, the expected tag
pointing at HEAD, and the expected GitHub origin.

Use --allow-dirty only while developing the release gate itself.
EOF
}

ALLOW_DIRTY=0
if (( $# > 0 )); then
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --allow-dirty)
      ALLOW_DIRTY=1
      shift
      ;;
  esac
fi

if (( $# != 0 )); then
  echo "Unexpected arguments." >&2
  usage >&2
  exit 2
fi

cd "$ROOT"

echo "== working tree =="
STATUS="$(git status --porcelain=v1 --untracked-files=normal)"
if [[ -n "$STATUS" ]]; then
  echo "$STATUS"
  if (( ALLOW_DIRTY == 0 )); then
    echo "Working tree is not clean. Commit or remove source changes before the final release push." >&2
    exit 1
  fi
  echo "working_tree_dirty_allowed"
else
  echo "working_tree_clean_ok"
fi

echo
echo "== release version =="
VERSION="$(
  /usr/bin/python3 - "$ROOT" <<'PY'
import json
import plistlib
import sys
from pathlib import Path

root = Path(sys.argv[1])
package = json.loads((root / "desktop/electron/package.json").read_text(encoding="utf-8"))
plist = plistlib.loads((root / "Resources/Info.plist").read_bytes())

electron_version = package.get("version")
short_version = plist.get("CFBundleShortVersionString")
bundle_version = plist.get("CFBundleVersion")

if not electron_version:
    raise SystemExit("desktop/electron/package.json is missing version.")
if electron_version != short_version:
    raise SystemExit(f"Electron version {electron_version} does not match CFBundleShortVersionString {short_version}.")
if electron_version != bundle_version:
    raise SystemExit(f"Electron version {electron_version} does not match CFBundleVersion {bundle_version}.")

print(electron_version)
PY
)"
EXPECTED_TAG="v$VERSION"
echo "release_version_ok $VERSION"

echo
echo "== release tag =="
if ! git rev-parse -q --verify "refs/tags/$EXPECTED_TAG" >/dev/null; then
  echo "Missing local release tag: $EXPECTED_TAG" >&2
  exit 1
fi

TAG_COMMIT="$(git rev-list -n 1 "$EXPECTED_TAG")"
HEAD_COMMIT="$(git rev-parse HEAD)"
if [[ "$TAG_COMMIT" != "$HEAD_COMMIT" ]]; then
  echo "Release tag $EXPECTED_TAG points at $TAG_COMMIT, but HEAD is $HEAD_COMMIT." >&2
  echo "If $EXPECTED_TAG has not been pushed, the better fix is to commit intended changes and move the local tag to HEAD before first push." >&2
  echo "If $EXPECTED_TAG has already been pushed, create the next version tag instead." >&2
  exit 1
fi
echo "release_tag_points_at_head_ok $EXPECTED_TAG"

echo
echo "== origin =="
REMOTE_URL="$(git remote get-url origin 2>/dev/null || true)"
case "$REMOTE_URL" in
  "https://github.com/ggglitter/auto-translator-native"|\
  "https://github.com/ggglitter/auto-translator-native.git"|\
  "git@github.com:ggglitter/auto-translator-native.git")
    echo "origin_ok $REMOTE_URL"
    ;;
  "")
    echo "Missing origin remote." >&2
    exit 1
    ;;
  *)
    echo "Unexpected origin remote: $REMOTE_URL" >&2
    exit 1
    ;;
esac

echo
echo "release_gate_ok"
