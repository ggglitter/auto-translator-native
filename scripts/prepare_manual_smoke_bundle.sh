#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}/.."
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="/tmp/autotranslator-manual-bundle-$STAMP"
APP_SOURCE="$ROOT/Auto Translator Native.app"
APP_TARGET="$OUT/Auto Translator Native.app"

cd "$ROOT"

./build.sh >/dev/null

FIXTURE_OUTPUT="$(./scripts/make_manual_smoke_fixtures.sh)"
FIXTURE_DIR="$(printf "%s\n" "$FIXTURE_OUTPUT" | sed -n '1p')"

mkdir -p "$OUT/fixtures"
/usr/bin/ditto "$APP_SOURCE" "$APP_TARGET"
/usr/bin/ditto "$FIXTURE_DIR" "$OUT/fixtures"

cat > "$OUT/README.txt" <<TXT
Auto Translator Native manual smoke bundle

Generated: $STAMP

1. Open this folder in Finder:
   $OUT

2. Double-click:
   Auto Translator Native.app

3. Add or drag these files into the app:
   fixtures/sample.txt
   fixtures/sample.md
   fixtures/sample.docx

4. Follow the checklist in the repo:
   $ROOT/docs/MANUAL_SMOKE_CHECKLIST.md

5. Record findings in:
   $ROOT/docs/MANUAL_SMOKE_FINDINGS.md

Do not paste real API keys into repo files, terminal logs, or chat. If testing real API calls, enter keys only in the app UI so they stay in macOS Keychain.
TXT

./scripts/verify_manual_smoke_bundle.sh "$OUT" >/dev/null

echo "$OUT"
echo "$APP_TARGET"
echo "$OUT/fixtures/sample.txt"
echo "$OUT/fixtures/sample.md"
echo "$OUT/fixtures/sample.docx"
echo "$OUT/README.txt"
