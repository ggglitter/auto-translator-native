# Handoff

Last updated: 2026-06-27

## Current Goal

Auto Translator Native has been promoted into a local formal source repo at `/Users/laura/Downloads/AutoTranslatorDeliverables/SourceRepo`.

Original promotion was local-only, but the current user goal has changed to GitHub-hosted code, Windows/macOS builds, and OTA.

Current publication state:

- GitHub repo has been created by the user: `https://github.com/ggglitter/auto-translator-native`
- local root commit exists: `8c732c4 Promote Auto Translator Native with desktop release pipeline`
- local tag exists: `v1.0.0`
- local remote is configured: `origin https://github.com/ggglitter/auto-translator-native.git`
- SSH push failed in the user's terminal with `Permission denied (publickey)`
- HTTPS push, custom domain, and separate HTTPS OTA host work are intentionally deferred until the final gate
- real API keys must stay out of repo files and chat

## Resume Checks

Run these first:

```zsh
git status --short --branch --ignored
git remote -v
rg -n "sk-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{20,}|Bearer [A-Za-z0-9._-]{20,}" -S . -g '!work' -g '!Auto Translator Native.app'
```

Or run the combined local-only gate:

```zsh
./scripts/check_repo_safety.sh
```

Expected current shape:

- branch: `main`
- state: clean tracked tree at local commit `8c732c4`
- tag: `v1.0.0`
- remote: `origin https://github.com/ggglitter/auto-translator-native.git`
- ignored local outputs: `Auto Translator Native.app/`, `work/`

## Verified Local Artifacts

- Preflight passed with `./scripts/preflight_local.sh`.
- Latest fixture directory: `/tmp/autotranslator-manual-smoke-20260627-133340`.
- Latest manual smoke bundle: `/tmp/autotranslator-manual-bundle-20260627-112011`.
- Latest package: `/tmp/autotranslator-packages-20260627-111622/AutoTranslatorNative-1.0.0-20260627-111622.zip`.
- Package checksum: `/tmp/autotranslator-packages-20260627-111622/AutoTranslatorNative-1.0.0-20260627-111622.zip.sha256`.
- Package manifest: `/tmp/autotranslator-packages-20260627-111622/manifest.json`.
- `shasum -c`, `unzip -t`, `python3 -m json.tool`, `./scripts/verify_local_package.sh`, and `codesign --verify --deep` passed for the relevant local artifacts.
- `./scripts/verify_local_package.sh` can re-verify the latest package directory or manifest.
- `./scripts/check_repo_safety.sh` is the remote/ignored-output/real-secret pattern gate. It accepts no remote before publication or the expected `ggglitter/auto-translator-native` origin after publication setup.
- `docs/FIRST_COMMIT_PLAN.md` documents the exact first local commit boundary, but no staging or commit has been performed.
- `./scripts/check_first_commit_ready.sh` validates the planned first-commit candidate set without staging files; latest run passed with `first_commit_ready_ok`.
- `./scripts/preflight_local.sh` now runs first-commit readiness and cross-platform release config before extraction/build/launch smoke; latest run passed with `preflight_ok`.
- `./scripts/verify_manual_smoke_bundle.sh` can re-verify a manual smoke bundle before the user opens it.
- Cross-platform release track: `desktop/electron/`.
- GitHub Actions workflow: `.github/workflows/desktop-release.yml`.
- GitHub Release / OTA plan: `docs/GITHUB_RELEASE_OTA.md`.
- Release artifact checklist: `docs/RELEASE_ARTIFACTS.md`.
- Release artifact checker: `./scripts/check_release_artifacts.sh`.
- Signing/notarization plan: `docs/SIGNING_NOTARIZATION_PLAN.md`.
- GitHub publish runbook: `docs/GITHUB_PUBLISH_RUNBOOK.md`.
- Electron OTA UI has check, download, and install controls wired to `electron-updater`.
- GitHub repo: `ggglitter/auto-translator-native`.
- Secret scanning scripts now resolve `rg` from PATH or common Homebrew locations and fail if it is unavailable.

## Known Limitation

LaunchServices `open` reports `kLSNoExecutableErr` in this sandbox even for a generated minimal app. Treat this as an environment limitation. Manual double-click/open verification should be done in the user's normal desktop session.

Hidden `.agents` and `.codex` directories could not be created because the sandbox rejects those writes, and the approval service rejected the escalation request. Do not bypass this. Use `AGENTS.md` plus `docs/CONTINUE_APP.md`, `docs/status.md`, `docs/ROADMAP.md`, and this handoff file as the durable state until hidden repo-local state is available.

## Next Small Step

Continue local/offline release readiness first. Do not push, configure a domain, or switch to a separate HTTPS OTA host until the user resumes that final gate.

Useful next checks:

```zsh
./scripts/check_cross_platform_release.sh
./scripts/preflight_local.sh
```

Before the final HTTPS push/tag gate, run:

```zsh
./scripts/check_release_gate.sh
```

If local commits were added after `v1.0.0` was created, and the tag has not been pushed, the better fix is to move the local `v1.0.0` tag to the final commit before first push. If the tag has already been pushed, create the next version tag instead.

After GitHub Actions or local Electron builds produce artifacts, validate them with:

```zsh
./scripts/check_release_artifacts.sh /path/to/release-artifacts
```

Manual app-window pass still needs real desktop verification using `/tmp/autotranslator-manual-bundle-20260627-112011`:

1. Double-click `Auto Translator Native.app`.
2. Add or drag `fixtures/sample.txt`, `fixtures/sample.md`, and `fixtures/sample.docx`.
3. Verify extraction preview, selectable rows, clearing behavior, and missing-key validation.
4. Record real results in `docs/MANUAL_SMOKE_FINDINGS.md`.

Use real provider keys only through the app UI and macOS Keychain.

The user has explicitly authorized GitHub publication, Windows/macOS builds, and OTA, but then asked to leave HTTPS and domain work until the end. Before claiming completion later, verify an authenticated HTTPS GitHub path is available, push the repo and tag, then confirm GitHub Actions/release evidence. `gh` is currently unavailable locally.
