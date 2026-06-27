#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}/.."
ELECTRON_DIR="$ROOT/desktop/electron"
WORKFLOW="$ROOT/.github/workflows/desktop-release.yml"

cd "$ROOT"

echo "== electron source files =="
for file in \
  "$ELECTRON_DIR/package.json" \
  "$ELECTRON_DIR/src/main.js" \
  "$ELECTRON_DIR/src/preload.js" \
  "$ELECTRON_DIR/src/renderer/index.html" \
  "$ELECTRON_DIR/src/renderer/styles.css" \
  "$ELECTRON_DIR/src/renderer/app.js" \
  "$ELECTRON_DIR/scripts/check-config.mjs"
do
  [[ -f "$file" ]] || {
    echo "Missing Electron file: $file" >&2
    exit 1
  }
done
echo "electron_files_ok"

echo
echo "== package json =="
/usr/bin/python3 - "$ELECTRON_DIR/package.json" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
build = data.get("build", {})
publish = (build.get("publish") or [{}])[0]

assert data["name"] == "auto-translator-native-desktop"
assert build["appId"] == "com.codex.autotranslator.native"
assert publish["provider"] == "github"
assert publish["owner"] == "ggglitter"
assert publish["repo"] == "auto-translator-native"
for key in ["electron-updater", "mammoth", "pdf-parse"]:
    assert key in data["dependencies"], key
for key in ["electron", "electron-builder"]:
    assert key in data["devDependencies"], key
for key in ["dist:mac", "dist:win", "check"]:
    assert key in data["scripts"], key
print("package_json_ok")
PY

echo
echo "== github workflow =="
[[ -f "$WORKFLOW" ]] || {
  echo "Missing workflow: $WORKFLOW" >&2
  exit 1
}
grep -q "macos-14" "$WORKFLOW"
grep -q "windows-latest" "$WORKFLOW"
grep -q "gh release create" "$WORKFLOW"
grep -Fq "latest*.yml" "$WORKFLOW"
echo "github_workflow_ok"

echo
echo "== docs =="
[[ -f "$ROOT/docs/GITHUB_RELEASE_OTA.md" ]]
grep -q "electron-updater" "$ROOT/docs/GITHUB_RELEASE_OTA.md"
grep -q "ggglitter/auto-translator-native" "$ROOT/docs/GITHUB_RELEASE_OTA.md"
echo "release_docs_ok"

echo
echo "cross_platform_release_config_ok"
