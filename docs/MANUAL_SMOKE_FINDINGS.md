# Manual Smoke Findings

Last updated: 2026-06-27

## Latest Automated Preflight

- Status: pass
- Command: `./scripts/preflight_local.sh`
- Last run: 2026-06-27
- Fixture directory: `/tmp/autotranslator-manual-smoke-20260627-200256`
- Covers: first-commit readiness, cross-platform release config, extraction smoke, disposable fixture generation, local app build, app launch smoke, real-secret pattern scan
- Result: `preflight_ok`
- Note: LaunchServices `open` returned `kLSNoExecutableErr` in the sandbox. A generated minimal `.app` fails the same way, so `smoke_launch_app.sh` records this as an environment limitation and passes bundle structure/codesign checks.

## App Window Pass

- Status: pending manual run
- Checklist: `docs/MANUAL_SMOKE_CHECKLIST.md`
- Fixture command: `./scripts/make_manual_smoke_fixtures.sh`
- Manual bundle command: `./scripts/prepare_manual_smoke_bundle.sh`
- Latest manual bundle: `/tmp/autotranslator-manual-bundle-20260627-112011`
- Latest bundle verification: `./scripts/verify_manual_smoke_bundle.sh` passed with `manual_smoke_bundle_verify_ok`.

## Latest Local Package

- Status: pass
- Command: `./scripts/package_local_app.sh`
- Package: `/tmp/autotranslator-packages-20260627-111622/AutoTranslatorNative-1.0.0-20260627-111622.zip`
- Checksum: `/tmp/autotranslator-packages-20260627-111622/AutoTranslatorNative-1.0.0-20260627-111622.zip.sha256`
- Manifest: `/tmp/autotranslator-packages-20260627-111622/manifest.json`
- Result: `shasum -c`, `unzip -t`, `python3 -m json.tool`, and `./scripts/verify_local_package.sh` passed

## Latest Release Assets

- Status: pass
- Release tag: `v1.0.0`
- Published commit: `03a9c96 Add ad-hoc mac release signing`
- GitHub repo: `https://github.com/ggglitter/auto-translator-native`
- Asset directory: `/Users/laura/Downloads/AutoTranslatorDeliverables/ReleaseAssets-v1.0.0`
- Artifact check: `./scripts/check_release_artifacts.sh /Users/laura/Downloads/AutoTranslatorDeliverables/ReleaseAssets-v1.0.0` passed with `release_artifacts_ok`
- macOS ZIP strict codesign: passed after extracting `Auto.Translator.Native-1.0.0-arm64-mac.zip` and running strict deep verification on the contained app
- macOS DMG verification: `hdiutil verify /Users/laura/Downloads/AutoTranslatorDeliverables/ReleaseAssets-v1.0.0/Auto.Translator.Native-1.0.0-arm64.dmg` passed
- Remaining release hardening: mac Developer ID signing/notarization, Windows code signing, and Intel/universal macOS builds

## Findings

- LaunchServices `open` returned `kLSNoExecutableErr` in the sandbox for the promoted app, the original source-output app, and a generated minimal `.app`. Manual double-click/open verification on the user's desktop session is still required.
