# Smoke Tests

The local extraction smoke test verifies text extraction without network access or API keys.

The full local preflight runs the repo safety gate, first-commit readiness gate, cross-platform release config check, GitHub workflow check, signing readiness check, extraction smoke, fixture generation, app build, and launch-structure smoke:

```zsh
./scripts/preflight_local.sh
```

The repo safety check verifies local-only repository boundaries without modifying Git state:

```zsh
./scripts/check_repo_safety.sh
```

It checks that Git remote state is either absent or the expected `ggglitter/auto-translator-native` origin, local build outputs remain ignored, and no real-looking API key/token patterns are present in repo files. Secret scanning requires `rg`; the scripts fail if `rg` cannot be found in PATH or common Homebrew locations.

The first commit readiness check verifies the planned source/doc/script candidate set without staging files:

```zsh
./scripts/check_first_commit_ready.sh
```

It checks the repo safety gate, lists the candidate files, rejects local output or secret-like paths, verifies shell scripts are executable, and scans the candidate set for real-looking API key/token patterns.

The local package verifier checks an existing zip package and its `manifest.json`:

```zsh
./scripts/verify_local_package.sh /tmp/autotranslator-packages-20260627-111040
```

It verifies JSON syntax, manifest consistency, checksum contents, zip integrity, required `.app` members, and local-only publishing/secrets flags.

The cross-platform release config check verifies Electron source, GitHub Actions, and OTA docs:

```zsh
./scripts/check_cross_platform_release.sh
```

The GitHub workflow check verifies release workflow triggers, permissions,
matrix entries, build steps, signing secret-name wiring, and publishing steps:

```zsh
./scripts/check_github_workflows.sh
```

The macOS release artifact check verifies macOS release assets beyond shape:

```zsh
./scripts/check_macos_release_artifact.sh --mac-arch arm64 /Users/laura/Downloads/AutoTranslatorDeliverables/ReleaseAssets-v1.0.0
```

It verifies updater metadata shape, DMG checksum validity, ZIP extraction,
strict app code signing, and the contained app executable architecture.

The signing readiness check verifies the repo's non-secret signing boundary:

```zsh
./scripts/check_signing_readiness.sh
```

It checks signing material ignore rules, rejects tracked certificate/key-like
files, verifies the non-secret signing checklist, confirms the Electron release
config shape, and scans for real-looking API key/token patterns.

The manual smoke bundle verifier checks an existing Finder-friendly manual bundle:

```zsh
./scripts/verify_manual_smoke_bundle.sh /tmp/autotranslator-manual-bundle-20260627-112011
```

It verifies bundle paths, `.app` structure, ad-hoc signature, fixture integrity, DOCX zip integrity, and real-looking API key/token patterns in text fixtures.

Run:

```zsh
./scripts/smoke_extract.sh
```

The script generates temporary TXT and DOCX fixtures, compiles `Sources/TextProcessing.swift` with a small Swift test runner, and checks:

- plain text extraction
- DOCX `word/document.xml` paragraph, line break, tab, and table-cell extraction
- text chunk splitting

It does not call translation APIs and does not read or write real API keys.
