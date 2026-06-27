#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}/.."
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
  echo "ripgrep (rg) is required for secret scanning but was not found in PATH or common Homebrew locations." >&2
  exit 1
fi

cd "$ROOT"

echo "== signing ignore rules =="
for pattern in \
  ".env" \
  ".env.*" \
  "*.key" \
  "*.pem" \
  "*.cer" \
  "*.p12" \
  "*.pfx" \
  "*.p8" \
  "*.certSigningRequest" \
  "*.mobileprovision" \
  "*.provisionprofile"
do
  grep -Fxq "$pattern" .gitignore || {
    echo "Missing .gitignore signing/secret rule: $pattern" >&2
    exit 1
  }
done
echo "signing_ignore_rules_ok"

echo
echo "== tracked signing material =="
TRACKED_SIGNING_MATERIAL="$(git ls-files -- \
  ".env" \
  ".env.*" \
  "*.key" \
  "*.pem" \
  "*.cer" \
  "*.p12" \
  "*.pfx" \
  "*.p8" \
  "*.certSigningRequest" \
  "*.mobileprovision" \
  "*.provisionprofile")"
if [[ -n "$TRACKED_SIGNING_MATERIAL" ]]; then
  echo "$TRACKED_SIGNING_MATERIAL"
  echo "Signing material or local secret files are tracked by Git." >&2
  exit 1
fi
echo "tracked_signing_material_absent_ok"

echo
echo "== signing docs =="
[[ -f docs/SIGNING_NOTARIZATION_PLAN.md ]] || {
  echo "Missing docs/SIGNING_NOTARIZATION_PLAN.md" >&2
  exit 1
}
[[ -f docs/SIGNING_SECRETS_CHECKLIST.md ]] || {
  echo "Missing docs/SIGNING_SECRETS_CHECKLIST.md" >&2
  exit 1
}
for token in \
  "MAC_CSC_LINK" \
  "MAC_CSC_KEY_PASSWORD" \
  "APPLE_API_KEY" \
  "APPLE_API_KEY_ID" \
  "APPLE_API_ISSUER" \
  "APPLE_ID" \
  "APPLE_APP_SPECIFIC_PASSWORD" \
  "APPLE_TEAM_ID" \
  "WIN_CSC_LINK" \
  "WIN_CSC_KEY_PASSWORD"
do
  grep -q "$token" docs/SIGNING_SECRETS_CHECKLIST.md || {
    echo "Signing checklist is missing non-secret name: $token" >&2
    exit 1
  }
done
echo "signing_docs_ok"

echo
echo "== signing workflow wiring =="
WORKFLOW=".github/workflows/desktop-release.yml"
[[ -f "$WORKFLOW" ]] || {
  echo "Missing workflow: $WORKFLOW" >&2
  exit 1
}
for token in \
  "secrets.MAC_CSC_LINK" \
  "secrets.MAC_CSC_KEY_PASSWORD" \
  "secrets.APPLE_API_KEY" \
  "secrets.APPLE_API_KEY_ID" \
  "secrets.APPLE_API_ISSUER" \
  "secrets.APPLE_ID" \
  "secrets.APPLE_APP_SPECIFIC_PASSWORD" \
  "secrets.APPLE_TEAM_ID" \
  "secrets.WIN_CSC_LINK" \
  "secrets.WIN_CSC_KEY_PASSWORD"
do
  grep -q "$token" "$WORKFLOW" || {
    echo "Workflow is missing signing secret reference: $token" >&2
    exit 1
  }
done
grep -q "Build macOS desktop artifact" "$WORKFLOW" || {
  echo "Workflow is missing separate macOS build step." >&2
  exit 1
}
grep -q "Build Windows desktop artifact" "$WORKFLOW" || {
  echo "Workflow is missing separate Windows build step." >&2
  exit 1
}
echo "signing_workflow_wiring_ok"

echo
echo "== electron release config =="
/usr/bin/python3 - "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
package = json.loads((root / "desktop/electron/package.json").read_text(encoding="utf-8"))
adhoc_hook = (root / "desktop/electron/scripts/adhoc-sign-mac.cjs").read_text(encoding="utf-8")
build = package.get("build", {})
mac = build.get("mac", {})
win = build.get("win", {})
publish = (build.get("publish") or [{}])[0]

if build.get("afterPack") != "scripts/adhoc-sign-mac.cjs":
    raise SystemExit("Expected ad-hoc mac signing hook to stay explicit until production signing is wired.")
if publish.get("provider") != "github":
    raise SystemExit("Expected GitHub release provider for OTA metadata.")
if not {"dmg", "zip"}.issubset(set(mac.get("target", []))):
    raise SystemExit("mac.target must include dmg and zip.")

win_targets = win.get("target", [])
if not any(isinstance(item, dict) and item.get("target") == "nsis" for item in win_targets):
    raise SystemExit("win.target must include nsis.")
if "Production mac signing environment detected" not in adhoc_hook:
    raise SystemExit("ad-hoc mac signing hook must skip when production signing env is present.")
if "process.env.CSC_LINK" not in adhoc_hook or "process.env.CSC_NAME" not in adhoc_hook:
    raise SystemExit("ad-hoc mac signing hook must check CSC_LINK or CSC_NAME.")

print("electron_release_config_ok")
PY

echo
echo "== real secret pattern scan =="
if "$RG_BIN" -n "sk-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{20,}|Bearer [A-Za-z0-9._-]{20,}" -S . -g '!work' -g '!Auto Translator Native.app'; then
  echo "Potential real secret pattern found." >&2
  exit 1
fi
echo "signing_secret_pattern_scan_ok"

echo
echo "signing_readiness_ok"
