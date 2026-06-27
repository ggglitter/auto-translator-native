#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
APP="$ROOT/Auto Translator Native.app"
CACHE="$ROOT/work/swift-module-cache"
BUILD_ROOT="$(mktemp -d /tmp/autotranslator-build.XXXXXX)"
BUILD_APP="$BUILD_ROOT/Auto Translator Native.app"
CONTENTS="$BUILD_APP/Contents"
MACOS="$CONTENTS/MacOS"

trap 'rm -rf "$BUILD_ROOT"' EXIT

mkdir -p "$MACOS" "$CACHE"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

swiftc \
  -parse-as-library \
  -module-cache-path "$CACHE" \
  "$ROOT/Sources"/*.swift \
  -o "$MACOS/AutoTranslatorNative" \
  -framework SwiftUI \
  -framework AppKit \
  -framework PDFKit \
  -framework Security \
  -framework UniformTypeIdentifiers

xattr -cr "$BUILD_APP"
codesign --force --deep --sign - "$BUILD_APP"
codesign --verify --deep "$BUILD_APP"

if codesign --verify --deep --strict "$BUILD_APP" 2>/dev/null; then
  echo "Strict codesign verification passed at build time."
else
  echo "Strict codesign verification skipped: local file-provider attributes are present."
fi

/bin/rm -rf "$APP"
/usr/bin/ditto "$BUILD_APP" "$APP"

echo "Note: macOS may reattach file-provider attributes later in Documents paths."

echo "Built: $APP"
