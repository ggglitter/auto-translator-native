#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}/.."
INCLUDE_PATHS=(
  ".gitignore"
  "AGENTS.md"
  "README.md"
  "Resources"
  "Sources"
  "build.sh"
  "docs"
  "scripts"
  ".github"
  "desktop/electron"
)
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

echo "== repo safety gate =="
./scripts/check_repo_safety.sh

echo
echo "== first commit candidate files =="
FILES=("${(@f)$(git ls-files --cached --others --exclude-standard -- "${INCLUDE_PATHS[@]}")}")

if (( ${#FILES[@]} == 0 )); then
  echo "No untracked or staged candidate files found; source tree may already be committed."
  FILES=("${(@f)$(git ls-files -- "${INCLUDE_PATHS[@]}")}")
fi

printf "%s\n" "${FILES[@]}"

echo
echo "== excluded path check =="
for path in "${FILES[@]}"; do
  case "$path" in
    "Auto Translator Native.app"|\
    "Auto Translator Native.app/"*|\
    "work"|\
    "work/"*|\
    ".env"|\
    ".env."*|\
    *.key|\
    *.pem|\
    *.cer|\
    *.p12|\
    *.pfx|\
    *.p8|\
    *.certSigningRequest|\
    *.mobileprovision|\
    *.provisionprofile)
      echo "Excluded path is in first commit candidate set: $path" >&2
      exit 1
      ;;
  esac
done
echo "excluded_paths_absent_ok"

echo
echo "== executable script check =="
for script in scripts/*.sh build.sh; do
  [[ -x "$script" ]] || {
    echo "Script is not executable: $script" >&2
    exit 1
  }
done
echo "scripts_executable_ok"

echo
echo "== candidate real secret pattern scan =="
if "$RG_BIN" -n "sk-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{20,}|Bearer [A-Za-z0-9._-]{20,}" -S -- "${FILES[@]}"; then
  echo "Potential real secret pattern found in first commit candidate files." >&2
  exit 1
fi
echo "candidate_secret_pattern_scan_ok"

echo
echo "first_commit_ready_ok"
