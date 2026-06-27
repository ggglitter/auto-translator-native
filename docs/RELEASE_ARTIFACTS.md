# Release Artifacts

Last updated: 2026-06-27

This file defines the offline acceptance check for Windows/macOS desktop
artifacts. It does not require HTTPS, a custom domain, GitHub credentials, or
real API keys.

## Expected Files

A complete tag release artifact set should contain:

- macOS `.dmg`
- macOS `.zip`
- macOS `.zip.blockmap`
- Windows `.exe`
- Windows `.exe.blockmap`
- `latest-mac.yml`
- `latest.yml`

The updater YAML files must include `version`, `files`, and `sha512` entries.
The macOS metadata should reference the `.zip` payload. The Windows metadata
should reference the `.exe` installer.

For the next macOS release, prefer universal mac artifacts so both Apple
Silicon and Intel Macs are covered by the same updater feed. The `v1.0.0`
release assets are arm64-only and should be checked with `--mac-arch arm64`.

## Local Check

After downloading GitHub Actions artifacts or a GitHub Release asset bundle,
run:

```zsh
./scripts/check_release_artifacts.sh /path/to/release-artifacts
```

The script searches recursively, so it accepts either a merged release folder or
the separate `auto-translator-macos` and `auto-translator-windows` artifact
folders.

To check one platform at a time:

```zsh
./scripts/check_release_artifacts.sh --platform mac /path/to/auto-translator-macos
./scripts/check_release_artifacts.sh --platform windows /path/to/auto-translator-windows
```

To enforce a specific mac architecture in the filenames and `latest-mac.yml`:

```zsh
./scripts/check_release_artifacts.sh --platform mac --mac-arch universal /path/to/auto-translator-macos
./scripts/check_release_artifacts.sh --platform mac --mac-arch arm64 /Users/laura/Downloads/AutoTranslatorDeliverables/ReleaseAssets-v1.0.0
```

For a deeper macOS check that also verifies the DMG checksum, extracts the ZIP,
checks strict code signing, and verifies the contained app executable
architecture:

```zsh
./scripts/check_macos_release_artifact.sh --mac-arch universal /path/to/auto-translator-macos
./scripts/check_macos_release_artifact.sh --mac-arch arm64 /Users/laura/Downloads/AutoTranslatorDeliverables/ReleaseAssets-v1.0.0
```

To check a local Electron build output after dependencies are installed:

```zsh
cd desktop/electron
npm run dist:mac
cd ../..
./scripts/check_release_artifacts.sh --platform mac --mac-arch universal desktop/electron/dist
```

Run the Windows build on Windows:

```powershell
cd desktop/electron
npm run dist:win
```

Then run the artifact checker against `desktop/electron/dist` or the copied
artifact directory.

## What This Proves

Passing this check proves that the package set is structurally ready for a
GitHub Release style OTA feed.

Passing the macOS deep check additionally proves that the downloaded or local
macOS DMG checksum is valid, the ZIP contains a verifiable `.app`, and the app
binary matches the expected architecture.

It does not prove:

- the app was code signed
- macOS notarization passed
- Windows SmartScreen reputation is acceptable
- release assets are publicly reachable
- a custom HTTPS update host or domain is configured

Those are separate release gates and should be handled after the local artifact
shape is stable.
