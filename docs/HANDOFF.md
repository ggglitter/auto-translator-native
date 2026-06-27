# Handoff

Last updated: 2026-06-27

## Current Goal

Auto Translator Native has been promoted into a local formal source repo at `/Users/laura/Documents/翻译软件`.

Original promotion was local-only, but the current user goal has changed to GitHub-hosted code, Windows/macOS builds, and OTA.

Current publication state:

- no GitHub repo has been created yet in this environment
- no Git remote is configured yet
- nothing has been pushed yet
- no files have been staged or committed yet
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
- state: no commits yet, project files untracked
- remote: empty
- ignored local outputs: `Auto Translator Native.app/`, `work/`

## Verified Local Artifacts

- Preflight passed with `./scripts/preflight_local.sh`.
- Latest fixture directory: `/tmp/autotranslator-manual-smoke-20260627-123846`.
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
- GitHub publish runbook: `docs/GITHUB_PUBLISH_RUNBOOK.md`.
- Electron OTA UI has check, download, and install controls wired to `electron-updater`.
- Planned GitHub repo: `ggglitter/auto-translator-native`.
- Secret scanning scripts now resolve `rg` from PATH or common Homebrew locations and fail if it is unavailable.

## Known Limitation

LaunchServices `open` reports `kLSNoExecutableErr` in this sandbox even for a generated minimal app. Treat this as an environment limitation. Manual double-click/open verification should be done in the user's normal desktop session.

Hidden `.agents` and `.codex` directories could not be created because the sandbox rejects those writes, and the approval service rejected the escalation request. Do not bypass this. Use `AGENTS.md` plus `docs/CONTINUE_APP.md`, `docs/status.md`, `docs/ROADMAP.md`, and this handoff file as the durable state until hidden repo-local state is available.

## Next Small Step

Perform the manual app-window pass using `/tmp/autotranslator-manual-bundle-20260627-112011`:

1. Double-click `Auto Translator Native.app`.
2. Add or drag `fixtures/sample.txt`, `fixtures/sample.md`, and `fixtures/sample.docx`.
3. Verify extraction preview, selectable rows, clearing behavior, and missing-key validation.
4. Record real results in `docs/MANUAL_SMOKE_FINDINGS.md`.

Use real provider keys only through the app UI and macOS Keychain.

If the user explicitly authorizes the first local commit, follow `docs/FIRST_COMMIT_PLAN.md` and run the required checks first.

The user has explicitly authorized GitHub publication, Windows/macOS builds, and OTA. Before claiming completion, verify an authenticated GitHub path is available, push the repo, and confirm GitHub Actions/release evidence. `gh` is currently unavailable locally.
