#!/bin/zsh
set -euo pipefail

cat <<'TXT'
GitHub follow-up release commands for Auto Translator Native

Current local state:
  GitHub repo exists: https://github.com/ggglitter/auto-translator-native
  main and v1.0.0 are already pushed
  v1.0.0 points to release commit 03a9c96
  Origin is expected to be SSH: git@github.com:ggglitter/auto-translator-native.git

Use these for intentional follow-up source/docs pushes or future release tags.
Do not paste GitHub tokens, API keys, certificates, or passwords into repo files or chat.

Run from repo root:

  cd /Users/laura/Downloads/AutoTranslatorDeliverables/SourceRepo
  ./scripts/preflight_local.sh
  git status --short --branch --ignored
  git remote -v
  git push origin main

If preparing a new release tag:

  ./scripts/check_release_gate.sh
  git tag v1.0.1
  git push origin main
  git push origin v1.0.1

If origin is not the expected SSH URL:

  git remote set-url origin git@github.com:ggglitter/auto-translator-native.git

Do not rewrite v1.0.0. Create the next version tag instead.

After pushing a new release tag:
  Verify GitHub Actions > Desktop Release.
  Verify GitHub Releases contains macOS universal, Windows, blockmap, latest.yml, latest-mac.yml assets.
  Download the artifacts or release assets and run:
    ./scripts/check_release_artifacts.sh /path/to/release-artifacts
    ./scripts/check_release_artifacts.sh --platform mac --mac-arch universal /path/to/release-artifacts
TXT
