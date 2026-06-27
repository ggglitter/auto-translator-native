# GitHub Publish Runbook

Last updated: 2026-06-27

Target repo:

- GitHub: `ggglitter/auto-translator-native`
- SSH remote: `git@github.com:ggglitter/auto-translator-native.git`
- HTTPS remote: `https://github.com/ggglitter/auto-translator-native`

Do not paste GitHub tokens, API keys, Apple certificates, Windows signing certificates, or passwords into repo files or chat.

## 1. Create Empty GitHub Repo

Create `ggglitter/auto-translator-native` on GitHub.

For GitHub Release OTA without embedding credentials in the app, make the repo public or make release assets publicly accessible. If it must remain private, use GitHub Actions as build evidence and move OTA hosting to a separate HTTPS static host later.

Do not initialize the GitHub repo with README, `.gitignore`, or license; the local repo already contains source files.

## 2. Run Local Checks

From repo root:

```zsh
cd /Users/laura/Documents/翻译软件
./scripts/preflight_local.sh
```

Expected:

- `repo_safety_ok`
- `first_commit_ready_ok`
- `cross_platform_release_config_ok`
- `preflight_ok`

## 3. First Commit And Push

Prefer SSH if your GitHub SSH key is already configured:

```zsh
git add .github .gitignore AGENTS.md README.md Resources Sources build.sh desktop docs scripts
git status --short --branch --ignored
git commit -m "Promote Auto Translator Native with desktop release pipeline"
git remote add origin git@github.com:ggglitter/auto-translator-native.git
git push -u origin main
```

If SSH is not configured, use HTTPS only through your local Git credential manager. Do not paste tokens into repo files or chat:

```zsh
git remote add origin https://github.com/ggglitter/auto-translator-native.git
git push -u origin main
```

## 4. Trigger Windows/macOS Release Build

After `main` is pushed:

```zsh
git tag v1.0.0
git push origin v1.0.0
```

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

## 6. Signing Caveat

Unsigned Windows builds may show SmartScreen warnings.

Unsigned/not-notarized macOS builds may show Gatekeeper warnings, and production-grade macOS OTA needs Developer ID signing and notarization secrets configured outside the repo.

The app can still prove cross-platform packaging and OTA metadata before signing is complete, but do not claim polished production OTA until signing/notarization checks pass.
