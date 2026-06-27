#!/bin/zsh
set -euo pipefail

TARGET="${1:-}"
RG_BIN="$(command -v rg || true)"

if [[ -z "$RG_BIN" ]]; then
  for candidate in /opt/homebrew/bin/rg /usr/local/bin/rg; do
    if [[ -x "$candidate" ]]; then
      RG_BIN="$candidate"
      break
    fi
  done
fi

if [[ -z "$RG_BIN" ]]; then
  echo "ripgrep (rg) is required for fixture secret scanning but was not found in PATH or common Homebrew locations." >&2
  exit 1
fi

if [[ -z "$TARGET" ]]; then
  BUNDLES=(/tmp/autotranslator-manual-bundle-*(Nom))
  if (( ${#BUNDLES[@]} == 0 )); then
    echo "No manual smoke bundle found under /tmp/autotranslator-manual-bundle-*." >&2
    exit 1
  fi
  BUNDLE="${BUNDLES[1]}"
else
  BUNDLE="$TARGET"
fi

APP="$BUNDLE/Auto Translator Native.app"
README="$BUNDLE/README.txt"
TXT_FIXTURE="$BUNDLE/fixtures/sample.txt"
MD_FIXTURE="$BUNDLE/fixtures/sample.md"
DOCX_FIXTURE="$BUNDLE/fixtures/sample.docx"

echo "== bundle paths =="
[[ -d "$BUNDLE" ]] || {
  echo "Manual smoke bundle directory not found: $BUNDLE" >&2
  exit 1
}
[[ -d "$APP" ]] || {
  echo "App bundle not found: $APP" >&2
  exit 1
}
[[ -f "$README" ]] || {
  echo "README not found: $README" >&2
  exit 1
}
[[ -f "$TXT_FIXTURE" ]] || {
  echo "TXT fixture not found: $TXT_FIXTURE" >&2
  exit 1
}
[[ -f "$MD_FIXTURE" ]] || {
  echo "Markdown fixture not found: $MD_FIXTURE" >&2
  exit 1
}
[[ -f "$DOCX_FIXTURE" ]] || {
  echo "DOCX fixture not found: $DOCX_FIXTURE" >&2
  exit 1
}
echo "bundle_paths_ok"

echo
echo "== app structure =="
[[ -f "$APP/Contents/Info.plist" ]] || {
  echo "Info.plist missing from app bundle." >&2
  exit 1
}
[[ -x "$APP/Contents/MacOS/AutoTranslatorNative" ]] || {
  echo "App executable missing or not executable." >&2
  exit 1
}
[[ -f "$APP/Contents/_CodeSignature/CodeResources" ]] || {
  echo "Code signature resources missing from app bundle." >&2
  exit 1
}
BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "$APP/Contents/Info.plist")"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
if [[ "$BUNDLE_ID" != "com.codex.autotranslator.native" ]]; then
  echo "Unexpected bundle id: $BUNDLE_ID" >&2
  exit 1
fi
if [[ -z "$VERSION" ]]; then
  echo "Bundle version is empty." >&2
  exit 1
fi
echo "app_structure_ok"

echo
echo "== app signature =="
codesign --verify --deep "$APP"
echo "app_signature_ok"

echo
echo "== fixture integrity =="
grep -q "Auto Translator manual smoke file" "$TXT_FIXTURE" || {
  echo "TXT fixture content mismatch." >&2
  exit 1
}
grep -q "Auto Translator Smoke" "$MD_FIXTURE" || {
  echo "Markdown fixture content mismatch." >&2
  exit 1
}
/usr/bin/unzip -t "$DOCX_FIXTURE" >/dev/null
/usr/bin/unzip -p "$DOCX_FIXTURE" word/document.xml | grep -q "Manual smoke DOCX paragraph" || {
  echo "DOCX fixture content mismatch." >&2
  exit 1
}
echo "fixture_integrity_ok"

echo
echo "== fixture secret pattern scan =="
if "$RG_BIN" -n "sk-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{20,}|Bearer [A-Za-z0-9._-]{20,}" -S "$README" "$TXT_FIXTURE" "$MD_FIXTURE"; then
  echo "Potential real secret pattern found in manual smoke bundle text files." >&2
  exit 1
fi
echo "fixture_secret_pattern_scan_ok"

echo
echo "$BUNDLE"
echo "manual_smoke_bundle_verify_ok"
