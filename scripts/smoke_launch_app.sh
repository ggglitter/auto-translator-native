#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}/.."
APP="$ROOT/Auto Translator Native.app"
INFO="$APP/Contents/Info.plist"
EXECUTABLE="$APP/Contents/MacOS/AutoTranslatorNative"

minimal_open_works() {
  local tmp app
  tmp="$(mktemp -d /tmp/autotranslator-minimal-open.XXXXXX)"
  app="$tmp/Minimal.app"
  mkdir -p "$app/Contents/MacOS"
  cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Minimal</string>
  <key>CFBundleIdentifier</key>
  <string>com.codex.autotranslator.launchcheck</string>
  <key>CFBundleName</key>
  <string>Minimal</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
</dict>
</plist>
PLIST
  cat > "$app/Contents/MacOS/Minimal" <<'SH'
#!/bin/zsh
exit 0
SH
  chmod +x "$app/Contents/MacOS/Minimal"
  open -n "$app" >/dev/null 2>&1
  local open_status=$?
  rm -rf "$tmp"
  return "$open_status"
}

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "launch_smoke_failed: app executable is missing; run ./build.sh first" >&2
  exit 1
fi

if [[ ! -f "$INFO" ]]; then
  echo "launch_smoke_failed: Info.plist is missing" >&2
  exit 1
fi

BUNDLE_EXECUTABLE="$(plutil -extract CFBundleExecutable raw "$INFO")"
if [[ "$BUNDLE_EXECUTABLE" != "AutoTranslatorNative" ]]; then
  echo "launch_smoke_failed: CFBundleExecutable is '$BUNDLE_EXECUTABLE'" >&2
  exit 1
fi

codesign --verify --deep "$APP"

if [[ "${AUTOTRANSLATOR_SKIP_OPEN_SMOKE:-0}" == "1" ]]; then
  echo "launch_smoke_structure_ok"
  exit 0
fi

OPEN_OUTPUT="$(open -n "$APP" 2>&1)" || {
  if [[ "${AUTOTRANSLATOR_STRICT_OPEN_SMOKE:-0}" == "1" ]]; then
    echo "$OPEN_OUTPUT" >&2
    echo "launch_smoke_failed: LaunchServices could not open the app" >&2
    exit 1
  fi

  if minimal_open_works; then
    echo "$OPEN_OUTPUT" >&2
    echo "launch_smoke_failed: LaunchServices can open a minimal app, but not Auto Translator Native" >&2
    exit 1
  fi

  echo "$OPEN_OUTPUT" >&2
  echo "launch_smoke_open_skipped: LaunchServices open is unavailable in this environment, including for a minimal app"
  echo "launch_smoke_structure_ok"
  exit 0
}

sleep 1
osascript -e 'tell application id "com.codex.autotranslator.native" to quit' >/dev/null 2>&1 || true
echo "launch_smoke_ok"
