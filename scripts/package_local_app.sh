#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}/.."
STAMP="$(date +%Y%m%d-%H%M%S)"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$ROOT/Resources/Info.plist")"
BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "$ROOT/Resources/Info.plist")"
OUT="/tmp/autotranslator-packages-$STAMP"
APP="$ROOT/Auto Translator Native.app"
ZIP="$OUT/AutoTranslatorNative-$VERSION-$STAMP.zip"
CHECKSUM="$ZIP.sha256"
MANIFEST="$OUT/manifest.json"

cd "$ROOT"

./build.sh >/dev/null

mkdir -p "$OUT"

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
/usr/bin/shasum -a 256 "$ZIP" > "$CHECKSUM"
/usr/bin/shasum -a 256 -c "$CHECKSUM" >/dev/null
/usr/bin/unzip -t "$ZIP" >/dev/null

SHA256="$(/usr/bin/awk '{print $1}' "$CHECKSUM")"
ZIP_SIZE_BYTES="$(/usr/bin/stat -f%z "$ZIP")"
GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "$MANIFEST" <<JSON
{
  "app": "Auto Translator Native",
  "bundle_id": "$BUNDLE_ID",
  "version": "$VERSION",
  "generated_at": "$GENERATED_AT",
  "artifact_type": "local_ad_hoc_zip",
  "notarized": false,
  "zip_path": "$ZIP",
  "zip_sha256_path": "$CHECKSUM",
  "zip_sha256": "$SHA256",
  "zip_size_bytes": $ZIP_SIZE_BYTES,
  "verification": {
    "shasum_check": "passed",
    "unzip_test": "passed"
  },
  "publishing": {
    "github_created": false,
    "pushed": false,
    "uploaded": false
  },
  "secrets": {
    "real_api_keys_included": false,
    "key_storage": "macOS Keychain through app UI"
  }
}
JSON

/usr/bin/python3 -m json.tool "$MANIFEST" >/dev/null
./scripts/verify_local_package.sh "$MANIFEST" >/dev/null

echo "$OUT"
echo "$ZIP"
echo "$CHECKSUM"
echo "$MANIFEST"
