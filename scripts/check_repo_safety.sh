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

echo "== git state =="
git status --short --branch --ignored

echo
echo "== remote check =="
REMOTE_OUTPUT="$(git remote -v)"
if [[ -n "$REMOTE_OUTPUT" ]]; then
  EXPECTED_REMOTE_PATTERN='^(origin[[:space:]]+(git@github.com:ggglitter/auto-translator-native.git|https://github.com/ggglitter/auto-translator-native)(\.git)?[[:space:]]+\((fetch|push)\))$'
  while IFS= read -r line; do
    if [[ ! "$line" =~ $EXPECTED_REMOTE_PATTERN ]]; then
      echo "$REMOTE_OUTPUT"
      echo "Unexpected Git remote configured. Expected only origin for ggglitter/auto-translator-native." >&2
      exit 1
    fi
  done <<< "$REMOTE_OUTPUT"
  echo "$REMOTE_OUTPUT"
  echo "expected_remote_ok"
else
  echo "remote_absent_ok"
fi

echo
echo "== ignored output check =="
if [[ -d "Auto Translator Native.app" ]]; then
  git check-ignore -q -- "Auto Translator Native.app" || {
    echo "Auto Translator Native.app is not ignored." >&2
    exit 1
  }
fi

if [[ -d "work" ]]; then
  git check-ignore -q -- "work" || {
    echo "work is not ignored." >&2
    exit 1
  }
fi

TRACKED_OUTPUTS="$(git ls-files -- "Auto Translator Native.app" "work")"
if [[ -n "$TRACKED_OUTPUTS" ]]; then
  echo "$TRACKED_OUTPUTS"
  echo "Local build outputs are tracked by Git." >&2
  exit 1
fi
echo "ignored_outputs_ok"

echo
echo "== real secret pattern scan =="
if "$RG_BIN" -n "sk-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{20,}|Bearer [A-Za-z0-9._-]{20,}" -S . -g '!work' -g '!Auto Translator Native.app'; then
  echo "Potential real secret pattern found." >&2
  exit 1
fi
echo "secret_pattern_scan_ok"

echo
echo "repo_safety_ok"
