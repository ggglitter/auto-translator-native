# GitHub Publish Runbook

Last updated: 2026-06-27

Target repo:

- GitHub: `ggglitter/auto-translator-native`
- Current SSH remote: `git@github.com:ggglitter/auto-translator-native.git`
- HTTPS remote option: `https://github.com/ggglitter/auto-translator-native.git`

Do not paste GitHub tokens, API keys, Apple certificates, Windows signing certificates, or passwords into repo files or chat.

## Current Local State

- The GitHub repo has already been created and published.
- `main` is pushed to GitHub.
- `v1.0.0` is pushed and must not be rewritten.
- Release commit `03a9c96 Add ad-hoc mac release signing` is the `v1.0.0` baseline.
- Current local follow-up work may live on later commits on `main`.

Use this runbook for follow-up release checks and future version tags.

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
- `github_workflows_ok`
- `preflight_ok`

## 3. Follow-Up Commit And Push

Do not create a commit unless there are intentional source or docs changes.

For a docs/source follow-up on `main`:

```zsh
git status --short --branch --ignored
./scripts/check_repo_safety.sh
./scripts/check_github_workflows.sh
git push origin main
```

For a future release tag, create a new version tag instead of moving `v1.0.0`:

```zsh
./scripts/check_release_gate.sh
git tag v1.0.1
git push origin main
git push origin v1.0.1
```

If Git prompts for authentication, use the browser, SSH agent, or local Git credential manager. Do not paste tokens into repo files or chat.

If the remote was changed accidentally, reset it to the expected SSH origin:

```zsh
git remote set-url origin git@github.com:ggglitter/auto-translator-native.git
```

`v1.0.0` has already been pushed, so do not rewrite or move that public tag. If more release changes are needed, create the next version instead, such as `v1.0.1`.

## 4. Trigger Windows/macOS Release Build

Pushing a `v*` tag should trigger the `Desktop Release` workflow.

The `Desktop Release` workflow should build:

- macOS universal `.dmg`
- macOS universal `.zip`
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
5. Confirm the intended release tag exists.
6. Confirm both Windows and macOS artifacts exist.
7. Confirm updater metadata files exist.

After downloading the artifacts or release assets locally, run:

```zsh
./scripts/check_release_artifacts.sh /path/to/release-artifacts
```

For the next macOS release, also enforce the universal mac artifact shape:

```zsh
./scripts/check_release_artifacts.sh --platform mac --mac-arch universal /path/to/release-artifacts
```

## 6. Signing Caveat

Unsigned Windows builds may show SmartScreen warnings.

Unsigned/not-notarized macOS builds may show Gatekeeper warnings, and production-grade macOS OTA needs Developer ID signing and notarization secrets configured outside the repo.

The app can still prove cross-platform packaging and OTA metadata before signing is complete, but do not claim polished production OTA until signing/notarization checks pass.

See `docs/SIGNING_NOTARIZATION_PLAN.md` for the non-secret signing plan.
