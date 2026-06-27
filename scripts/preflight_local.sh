#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}/.."

cd "$ROOT"

echo "== first commit readiness =="
./scripts/check_first_commit_ready.sh

echo
echo "== cross-platform release config =="
./scripts/check_cross_platform_release.sh

echo
echo "== signing readiness =="
./scripts/check_signing_readiness.sh

echo
echo "== extraction smoke =="
./scripts/smoke_extract.sh

echo
echo "== manual fixtures =="
FIXTURE_OUTPUT="$(./scripts/make_manual_smoke_fixtures.sh)"
echo "$FIXTURE_OUTPUT"

echo
echo "== build app =="
./build.sh

if [[ "${AUTOTRANSLATOR_SKIP_LAUNCH_SMOKE:-0}" != "1" ]]; then
  echo
  echo "== launch app smoke =="
  ./scripts/smoke_launch_app.sh
else
  echo
  echo "== launch app smoke skipped =="
fi

echo
echo "preflight_ok"
