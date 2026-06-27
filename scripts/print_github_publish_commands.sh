#!/bin/zsh
set -euo pipefail

cat <<'TXT'
GitHub publish commands for Auto Translator Native

Prerequisite:
  Create an empty GitHub repo named ggglitter/auto-translator-native.
  Do not paste GitHub tokens, API keys, certificates, or passwords into repo files or chat.

Run from repo root:

  cd /Users/laura/Documents/翻译软件
  ./scripts/preflight_local.sh
  git add .github .gitignore AGENTS.md README.md Resources Sources build.sh desktop docs scripts
  git status --short --branch --ignored
  git commit -m "Promote Auto Translator Native with desktop release pipeline"
  git remote add origin git@github.com:ggglitter/auto-translator-native.git
  git push -u origin main
  git tag v1.0.0
  git push origin v1.0.0

If SSH is not configured, use local Git credential manager with HTTPS:

  git remote add origin https://github.com/ggglitter/auto-translator-native.git
  git push -u origin main

After pushing v1.0.0:
  Verify GitHub Actions > Desktop Release.
  Verify GitHub Releases contains macOS, Windows, blockmap, latest.yml, latest-mac.yml assets.
TXT
