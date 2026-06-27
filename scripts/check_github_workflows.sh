#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}/.."
RELEASE_WORKFLOW="$ROOT/.github/workflows/desktop-release.yml"
SOURCE_WORKFLOW="$ROOT/.github/workflows/source-checks.yml"

cd "$ROOT"

echo "== workflow files =="
[[ -f "$RELEASE_WORKFLOW" ]] || {
  echo "Missing workflow: $RELEASE_WORKFLOW" >&2
  exit 1
}
[[ -f "$SOURCE_WORKFLOW" ]] || {
  echo "Missing workflow: $SOURCE_WORKFLOW" >&2
  exit 1
}
echo "desktop_release_workflow_present_ok"
echo "source_checks_workflow_present_ok"

echo
echo "== source checks triggers =="
grep -q "^  workflow_dispatch:" "$SOURCE_WORKFLOW" || {
  echo "Source Checks workflow must support manual workflow_dispatch." >&2
  exit 1
}
grep -q "^  push:" "$SOURCE_WORKFLOW" || {
  echo "Source Checks workflow must run on main pushes." >&2
  exit 1
}
grep -q "^  pull_request:" "$SOURCE_WORKFLOW" || {
  echo "Source Checks workflow must run on main pull requests." >&2
  exit 1
}
grep -q "^      - main" "$SOURCE_WORKFLOW" || {
  echo "Source Checks workflow must target main." >&2
  exit 1
}
echo "source_checks_triggers_ok"

echo
echo "== source checks permissions =="
grep -q "^permissions:" "$SOURCE_WORKFLOW"
grep -q "contents: read" "$SOURCE_WORKFLOW" || {
  echo "Source Checks workflow should only need contents: read." >&2
  exit 1
}
echo "source_checks_permissions_ok"

echo
echo "== source checks steps =="
for token in \
  "name: Source Checks" \
  "runs-on: macos-14" \
  "uses: actions/checkout@v4" \
  "brew install ripgrep" \
  "run: ./scripts/check_repo_safety.sh" \
  "run: ./scripts/check_cross_platform_release.sh" \
  "run: ./scripts/check_signing_readiness.sh" \
  "run: ./scripts/smoke_extract.sh"
do
  grep -Fq "$token" "$SOURCE_WORKFLOW" || {
    echo "Source Checks workflow is missing token: $token" >&2
    exit 1
  }
done
echo "source_checks_steps_ok"

echo
echo "== source checks isolation =="
for token in \
  "contents: write" \
  "gh release" \
  "actions/upload-artifact" \
  "secrets." \
  "electron-builder" \
  "npm run dist:mac" \
  "npm run dist:win"
do
  if grep -Fq "$token" "$SOURCE_WORKFLOW"; then
    echo "Source Checks workflow must not publish, sign, or build release artifacts: $token" >&2
    exit 1
  fi
done
echo "source_checks_isolation_ok"

echo
echo "== desktop release triggers =="
grep -q "^  workflow_dispatch:" "$RELEASE_WORKFLOW" || {
  echo "Desktop Release workflow must support manual workflow_dispatch." >&2
  exit 1
}
grep -q "^  push:" "$RELEASE_WORKFLOW" || {
  echo "Desktop Release workflow must run on tag pushes." >&2
  exit 1
}
grep -q '      - "v\*"' "$RELEASE_WORKFLOW" || {
  echo "Desktop Release workflow must include v* tag trigger." >&2
  exit 1
}
echo "desktop_release_triggers_ok"

echo
echo "== desktop release permissions =="
grep -q "^permissions:" "$RELEASE_WORKFLOW"
grep -q "contents: write" "$RELEASE_WORKFLOW" || {
  echo "Desktop Release workflow needs contents: write to publish releases." >&2
  exit 1
}
echo "desktop_release_permissions_ok"

echo
echo "== desktop release matrix =="
for token in \
  "macos-14" \
  "macos-universal" \
  "npm run dist:mac:universal" \
  "windows-latest" \
  "artifact: windows" \
  "npm run dist:win"
do
  grep -q "$token" "$RELEASE_WORKFLOW" || {
    echo "Desktop Release workflow is missing matrix token: $token" >&2
    exit 1
  }
done
echo "desktop_release_matrix_ok"

echo
echo "== desktop release build steps =="
for token in \
  "uses: actions/checkout@v4" \
  "uses: actions/setup-node@v4" \
  "node-version: \"20\"" \
  "run: npm install" \
  "run: npm run check" \
  "Build macOS desktop artifact" \
  "Build Windows desktop artifact" \
  "uses: actions/upload-artifact@v4"
do
  grep -q "$token" "$RELEASE_WORKFLOW" || {
    echo "Desktop Release workflow is missing build step token: $token" >&2
    exit 1
  }
done
echo "desktop_release_build_steps_ok"

echo
echo "== desktop release signing wiring =="
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
  grep -q "$token" "$RELEASE_WORKFLOW" || {
    echo "Desktop Release workflow is missing signing secret reference: $token" >&2
    exit 1
  }
done
echo "desktop_release_signing_wiring_ok"

echo
echo "== desktop release publishing =="
for token in \
  "uses: actions/download-artifact@v4" \
  "merge-multiple: true" \
  "gh release upload" \
  "gh release create" \
  "latest*.yml"
do
  grep -Fq "$token" "$RELEASE_WORKFLOW" || {
    echo "Desktop Release workflow is missing publish token: $token" >&2
    exit 1
  }
done
echo "desktop_release_publishing_ok"

echo
echo "github_workflows_ok"
