#!/bin/zsh
set -euo pipefail

cat <<'TXT'
GitHub final-gate publish commands for Auto Translator Native

Current local state:
  GitHub repo exists: https://github.com/ggglitter/auto-translator-native
  Local commit exists: 8c732c4 Promote Auto Translator Native with desktop release pipeline
  Local tag exists: v1.0.0
  Origin is expected to be HTTPS.

Use these only after the HTTPS/GitHub gate is resumed.
  Do not paste GitHub tokens, API keys, certificates, or passwords into repo files or chat.

Run from repo root:

  cd /Users/laura/Downloads/AutoTranslatorDeliverables/SourceRepo
  ./scripts/preflight_local.sh
  ./scripts/check_release_gate.sh
  git status --short --branch --ignored
  git remote -v
  git push -u origin main
  git push origin v1.0.0

If origin is not the expected HTTPS URL:

  git remote set-url origin https://github.com/ggglitter/auto-translator-native.git

If new commits were added after creating v1.0.0 and the tag has not been pushed:

  git tag -f v1.0.0 HEAD

If v1.0.0 has already been pushed, do not rewrite it. Create the next version tag instead.

After pushing v1.0.0:
  Verify GitHub Actions > Desktop Release.
  Verify GitHub Releases contains macOS, Windows, blockmap, latest.yml, latest-mac.yml assets.
  Download the artifacts or release assets and run:
    ./scripts/check_release_artifacts.sh /path/to/release-artifacts
TXT
