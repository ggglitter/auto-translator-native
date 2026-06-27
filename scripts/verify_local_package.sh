#!/bin/zsh
set -euo pipefail

TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
  MANIFESTS=(/tmp/autotranslator-packages-*/manifest.json(Nom))
  if (( ${#MANIFESTS[@]} == 0 )); then
    echo "No local package manifest found under /tmp/autotranslator-packages-*." >&2
    exit 1
  fi
  MANIFEST="${MANIFESTS[1]}"
elif [[ -d "$TARGET" ]]; then
  MANIFEST="$TARGET/manifest.json"
else
  MANIFEST="$TARGET"
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo "Package manifest not found: $MANIFEST" >&2
  exit 1
fi

echo "== manifest json =="
/usr/bin/python3 -m json.tool "$MANIFEST" >/dev/null
echo "manifest_json_ok"

echo
echo "== manifest consistency =="
MANIFEST_CHECK_OUTPUT="$(/usr/bin/python3 - "$MANIFEST" <<'PY'
import hashlib
import json
import sys
import zipfile
from pathlib import Path

manifest_path = Path(sys.argv[1])
data = json.loads(manifest_path.read_text(encoding="utf-8"))

required = [
    "app",
    "bundle_id",
    "version",
    "generated_at",
    "artifact_type",
    "notarized",
    "zip_path",
    "zip_sha256_path",
    "zip_sha256",
    "zip_size_bytes",
    "verification",
    "publishing",
    "secrets",
]
missing = [key for key in required if key not in data]
if missing:
    raise SystemExit(f"manifest missing required keys: {', '.join(missing)}")

if data["app"] != "Auto Translator Native":
    raise SystemExit("manifest app name mismatch")
if data["bundle_id"] != "com.codex.autotranslator.native":
    raise SystemExit("manifest bundle_id mismatch")
if data["artifact_type"] != "local_ad_hoc_zip":
    raise SystemExit("manifest artifact_type mismatch")
if data["notarized"] is not False:
    raise SystemExit("manifest notarized must be false for local ad-hoc package")

publishing = data["publishing"]
for key in ("github_created", "pushed", "uploaded"):
    if publishing.get(key) is not False:
        raise SystemExit(f"manifest publishing.{key} must be false")

secrets = data["secrets"]
if secrets.get("real_api_keys_included") is not False:
    raise SystemExit("manifest secrets.real_api_keys_included must be false")

zip_path = Path(data["zip_path"])
checksum_path = Path(data["zip_sha256_path"])
if not zip_path.is_file():
    raise SystemExit(f"zip not found: {zip_path}")
if not checksum_path.is_file():
    raise SystemExit(f"checksum not found: {checksum_path}")

actual_size = zip_path.stat().st_size
if actual_size != int(data["zip_size_bytes"]):
    raise SystemExit(f"zip size mismatch: manifest={data['zip_size_bytes']} actual={actual_size}")

digest = hashlib.sha256(zip_path.read_bytes()).hexdigest()
if digest != data["zip_sha256"]:
    raise SystemExit("zip sha256 mismatch against manifest")

checksum_text = checksum_path.read_text(encoding="utf-8").strip().split()
if not checksum_text:
    raise SystemExit("checksum file is empty")
if checksum_text[0] != digest:
    raise SystemExit("zip sha256 mismatch against checksum file")

with zipfile.ZipFile(zip_path) as archive:
    bad_file = archive.testzip()
    if bad_file:
        raise SystemExit(f"zip integrity failed at {bad_file}")
    names = set(archive.namelist())
    required_members = {
        "Auto Translator Native.app/",
        "Auto Translator Native.app/Contents/Info.plist",
        "Auto Translator Native.app/Contents/MacOS/AutoTranslatorNative",
        "Auto Translator Native.app/Contents/_CodeSignature/CodeResources",
    }
    missing_members = sorted(required_members - names)
    if missing_members:
        raise SystemExit("zip missing required members: " + ", ".join(missing_members))

print(zip_path)
print(checksum_path)
PY
)"
echo "manifest_consistency_ok"

ZIP_PATH="$(printf "%s\n" "$MANIFEST_CHECK_OUTPUT" | sed -n '1p')"
CHECKSUM_PATH="$(printf "%s\n" "$MANIFEST_CHECK_OUTPUT" | sed -n '2p')"

echo
echo "== checksum file =="
/usr/bin/shasum -a 256 -c "$CHECKSUM_PATH" >/dev/null
echo "checksum_file_ok"

echo
echo "== zip structure =="
/usr/bin/unzip -t "$ZIP_PATH" >/dev/null
echo "zip_structure_ok"

echo
echo "$MANIFEST"
echo "local_package_verify_ok"
