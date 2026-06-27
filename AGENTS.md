# Repo Guidance

This repository is the local formal source repo for Auto Translator Native.

## Boundaries

- Do not create a GitHub repository unless the user explicitly asks. The user has now explicitly asked for GitHub publication for the current goal.
- Do not push unless the user explicitly asks. The user has now explicitly asked for push/publication for the current goal.
- Do not stage or commit unless the user explicitly asks.
- Do not store real API keys, tokens, certificates, or provisioning profiles in this repo.
- API keys belong in macOS Keychain through the app UI, not in files.

## Before Editing

- Run `git status --short --branch`.
- Inspect the relevant diff before changing files.
- Preserve user changes and work with them instead of reverting them.

## Build

Use:

```zsh
./build.sh
```

Expected output is a regenerated local `Auto Translator Native.app` signed with ad-hoc signing. The build script verifies a clean temporary app bundle before copying it into the repo. Strict verification on the final copied app may be blocked by macOS file-provider attributes in Documents and should be treated as a packaging issue, not a source compile failure.

## Verification Ladder

1. Run `git status --short --branch`.
2. Run `./scripts/check_repo_safety.sh` or an equivalent hidden-aware secret scan that excludes `.git` and local output directories.
3. Run `./build.sh`.
4. Open the app locally and verify drag-and-drop, key saving, and missing-key validation.
5. Only use real API keys through macOS Keychain during manual smoke tests.
