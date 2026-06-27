# GitHub Release And OTA

Last updated: 2026-06-27

This repo has moved from local-only promotion to a GitHub-hosted, cross-platform desktop release flow.
`main` and `v1.0.0` have been pushed to GitHub. A custom update domain or any separate HTTPS update host remains a later gate; current work should focus on packaging, artifact verification, and production signing readiness.

## Target Repository

GitHub repository:

- `ggglitter/auto-translator-native`
- HTTPS remote option: `https://github.com/ggglitter/auto-translator-native.git`
- Current SSH remote: `git@github.com:ggglitter/auto-translator-native.git`

The local repo currently uses the SSH origin.

Do not store GitHub tokens, API keys, Apple certificates, or Windows signing certificates in repo files.

## Release Track

The cross-platform release track is `desktop/electron/`.

It uses:

- Electron for Windows/macOS desktop packaging
- `electron-builder` for `.exe`, `.dmg`, `.zip`, and updater metadata
- `electron-updater` for OTA checks from GitHub Releases
- Renderer controls for checking, downloading, and installing OTA updates
- GitHub Actions workflow `.github/workflows/desktop-release.yml`
- Exact Electron dependency versions in `desktop/electron/package.json` to reduce release-build drift before a lockfile is generated

The existing SwiftUI app remains as the native macOS source track under `Sources/`.

## Build And OTA Flow

1. Push source to GitHub.
2. Install dependencies in GitHub Actions with `npm install`.
3. Build universal macOS artifacts on `macos-14`.
4. Build Windows artifacts on `windows-latest`.
5. On a tag like `v1.0.0`, create a GitHub Release with:
   - macOS universal `.dmg`
   - macOS universal `.zip`
   - Windows `.exe`
   - `.blockmap`
   - `latest.yml`
   - `latest-mac.yml`
6. Packaged Electron apps check GitHub Release metadata through `electron-updater`.
7. Users can check for updates, download an available update, and install after download from the app window.

For GitHub Release OTA without embedding credentials in the app, the repository or release assets must be public. If the repo must remain private, use a separate HTTPS static update host later and keep GitHub Actions as build evidence.

Manual `workflow_dispatch` builds artifacts but does not create a release unless a `v*` tag is pushed.

## Required GitHub Checks

After pushing, verify:

```zsh
git remote -v
git status --short --branch
```

On GitHub, verify:

- Actions tab has a successful `Desktop Release` build.
- A tag build creates a Release.
- Release assets include both Windows and macOS artifacts plus updater YAML files.

After downloading artifacts or release assets, run:

```zsh
./scripts/check_release_artifacts.sh /path/to/release-artifacts
```

For the next macOS release, require universal mac output:

```zsh
./scripts/check_release_artifacts.sh --platform mac --mac-arch universal /path/to/release-artifacts
```

Use `docs/RELEASE_ARTIFACTS.md` as the artifact acceptance checklist.

## Secrets And Signing

No real API keys are needed for app builds.

For polished public distribution:

- macOS auto-update should use Developer ID signing and notarization.
- Windows distribution should eventually use code signing to reduce SmartScreen warnings.
- These signing secrets belong in GitHub Actions secrets or the OS keychain, not in repo files.

Initial unsigned/ad-hoc builds can prove packaging and GitHub Release metadata, but macOS user-facing OTA is not complete until signing/notarization is configured.

See `docs/SIGNING_NOTARIZATION_PLAN.md` for the non-secret signing plan.

## Local Validation

From repo root:

```zsh
./scripts/check_cross_platform_release.sh
```

For the exact local publish commands:

```zsh
./scripts/print_github_publish_commands.sh
```

From `desktop/electron/`, after dependencies are installed:

```zsh
npm run check
npm run dist:mac
npm run dist:win
```

`npm run dist:mac` delegates to `npm run dist:mac:universal`. If a fallback
single-architecture package is needed for debugging, use `npm run dist:mac:arm64`
or `npm run dist:mac:x64`.
