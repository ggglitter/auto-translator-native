# GitHub Publish Runbook

Last updated: 2026-06-27

Target repo:

- GitHub: `ggglitter/auto-translator-native`
- HTTPS remote: `https://github.com/ggglitter/auto-translator-native.git`
- SSH remote option: `git@github.com:ggglitter/auto-translator-native.git`

Do not paste GitHub tokens, API keys, Apple certificates, Windows signing certificates, or passwords into repo files or chat.

## Current Local State

- The GitHub repo has already been created by the user.
- Local commit exists: `8c732c4 Promote Auto Translator Native with desktop release pipeline`.
- Local tag exists: `v1.0.0`.
- Local remote is already configured as HTTPS origin.
- SSH push failed with `Permission denied (publickey)`.
- The user asked to leave HTTPS push, custom domain, and separate HTTPS OTA host work until the final gate.

Use this runbook only when that final GitHub/HTTPS gate is resumed.

## 1. Confirm GitHub Repo Shape

For GitHub Release OTA without embedding credentials in the app, make the repo public or make release assets publicly accessible. If it must remain private, use GitHub Actions as build evidence and move OTA hosting to a separate HTTPS static host later.

Do not initialize the GitHub repo with README, `.gitignore`, or license; the local repo already contains source files.

## 2. Run Local Checks

From repo root:

```zsh
cd /Users/laura/Downloads/AutoTranslatorDeliverables/SourceRepo
./scripts/preflight_local.sh
```

Expected:

- `repo_safety_ok`
- `first_commit_ready_ok`
- `cross_platform_release_config_ok`
- `preflight_ok`

## 3. First Commit And Push

The first local commit and tag already exist. Do not create a new commit just to push the existing state.

When the HTTPS gate is resumed, push from the current local repo:

```zsh
git status --short --branch --ignored
./scripts/check_release_gate.sh
git push -u origin main
git push origin v1.0.0
```

If the HTTPS push prompts for authentication, use the browser or local Git credential manager. Do not paste tokens into repo files or chat.

If the remote was changed accidentally, reset it to the expected HTTPS origin:

```zsh
git remote set-url origin https://github.com/ggglitter/auto-translator-native.git
```

If new local commits were added after creating `v1.0.0`, the release gate will fail because the tag points at the older commit. Since `v1.0.0` has not been pushed yet, the better fix is to commit the intended changes, move the local tag to the final commit, and then push:

```zsh
git tag -f v1.0.0 HEAD
```

If the tag has already been pushed by the time this happens, do not rewrite the public tag. Create the next version instead, such as `v1.0.1`.

## 4. Trigger Windows/macOS Release Build

Pushing the existing `v1.0.0` tag should trigger the `Desktop Release` workflow.

The `Desktop Release` workflow should build:

- macOS `.dmg`
- macOS `.zip`
- Windows `.exe`
- `.blockmap`
- `latest.yml`
- `latest-mac.yml`

## 5. Verify GitHub Evidence

On GitHub:

1. Open Actions.
2. Confirm `Desktop Release` succeeded on `macos-14`.
3. Confirm `Desktop Release` succeeded on `windows-latest`.
4. Open Releases.
5. Confirm tag `v1.0.0` exists.
6. Confirm both Windows and macOS artifacts exist.
7. Confirm updater metadata files exist.

After downloading the artifacts or release assets locally, run:

```zsh
./scripts/check_release_artifacts.sh /path/to/release-artifacts
```

## 6. Signing Caveat

Unsigned Windows builds may show SmartScreen warnings.

Unsigned/not-notarized macOS builds may show Gatekeeper warnings, and production-grade macOS OTA needs Developer ID signing and notarization secrets configured outside the repo.

The app can still prove cross-platform packaging and OTA metadata before signing is complete, but do not claim polished production OTA until signing/notarization checks pass.

See `docs/SIGNING_NOTARIZATION_PLAN.md` for the non-secret signing plan.
