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

To check a local Electron build output after dependencies are installed:

```zsh
cd desktop/electron
npm run dist:mac
cd ../..
./scripts/check_release_artifacts.sh --platform mac desktop/electron/dist
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

It does not prove:

- the app was code signed
- macOS notarization passed
- Windows SmartScreen reputation is acceptable
- release assets are publicly reachable
- a custom HTTPS update host or domain is configured

Those are separate release gates and should be handled after the local artifact
shape is stable.
