# Signing And Notarization Plan

Last updated: 2026-06-27

This plan documents the production signing path without storing any real
certificates, passwords, tokens, provisioning profiles, or API keys in the repo.

## Current Position

- Local SwiftUI builds are ad-hoc signed for development.
- Electron Windows/macOS packaging config exists under `desktop/electron/`.
- GitHub Actions can build unsigned or development-signed artifacts.
- Non-secret signing secret names live in `docs/SIGNING_SECRETS_CHECKLIST.md`.
- `./scripts/check_signing_readiness.sh` verifies that common signing material
  is ignored and not tracked.
- GitHub Actions maps signing secret names into the platform-specific build
  steps without storing secret values in the repo.
- User-facing macOS OTA should not be claimed complete until Developer ID
  signing and notarization are configured.
- Public Windows distribution should not be called polished until code signing
  is configured.

## macOS

Production macOS distribution needs:

- Apple Developer Program membership
- Developer ID Application certificate
- notarization credentials through GitHub Actions secrets or local keychain
- hardened runtime enabled in the Electron build configuration
- final verification with `spctl`, `codesign`, and a real launch test

Secrets should be supplied at build time only. Acceptable storage locations are
GitHub Actions secrets, the developer keychain, or a secure certificate store.
Do not commit `.p12`, `.cer`, `.mobileprovision`, private keys, API keys, or
notarization passwords.

CI-only environment variable wiring for `electron-builder` is in place. After
real secrets are added outside the repo, verify that the generated `.dmg` and
`.zip` are signed and notarized before publishing them as production OTA
assets.

## Windows

Production Windows distribution needs:

- a code signing certificate or trusted signing service
- CI-only access through GitHub Actions secrets or a secure signing provider
- verification of the `.exe` Authenticode signature
- a clean install/uninstall smoke test on Windows

Do not commit `.pfx`, private keys, certificate passwords, or signing service
tokens.

## Gate Order

1. Keep source and local checks clean.
2. Build macOS and Windows artifacts.
3. Validate artifact shape with `./scripts/check_release_artifacts.sh`.
4. Add signing secrets outside the repo.
5. Run `./scripts/check_signing_readiness.sh`.
6. Verify macOS signing and notarization.
7. Verify Windows signing.
8. Publish release assets.
9. Verify OTA update from an installed app.

HTTPS update hosting and any custom domain can remain a later gate.
