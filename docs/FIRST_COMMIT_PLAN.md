# First Commit Record

Last updated: 2026-06-27

The first local commit has been completed:

- Commit: `8c732c4 Promote Auto Translator Native with desktop release pipeline`
- Tag: `v1.0.0`
- Remote: `origin https://github.com/ggglitter/auto-translator-native.git`

Keep this file as the source boundary reference for future amendments. Do not stage, commit, or push additional changes unless the user explicitly authorizes that Git gate.

Current user goal authorizes GitHub publication and push eventually, but HTTPS push and domain/HTTPS update hosting are deferred until the final gate.

## Original Commit Boundary

The first local commit captured the promoted source repo and local durable state only.

Include:

- `.gitignore`
- `AGENTS.md`
- `README.md`
- `Resources/`
- `Sources/`
- `build.sh`
- `docs/`
- `scripts/`
- `.github/`
- `desktop/electron/`

Exclude:

- `Auto Translator Native.app/`
- `work/`
- `.env`, `.env.*`
- private keys, certificates, provisioning profiles, API keys, tokens, or chat-copied secrets
- signing secrets, GitHub tokens, release credentials, or notarization credentials

## Required Checks Before Future Staging

Run:

```zsh
./scripts/preflight_local.sh
```

Expected results:

- `repo_safety_ok`
- `first_commit_ready_ok`
- `preflight_ok`
- remote may be absent before publish or point to `ggglitter/auto-translator-native` after publish setup
- `Auto Translator Native.app/` and `work/` remain ignored
- real-secret pattern scan reports no matches

## Historical Local Commit Commands

These commands were the original first-commit shape. Do not re-run them unless intentionally creating a new commit after checking the current diff.

```zsh
git add .gitignore AGENTS.md README.md Resources Sources build.sh docs scripts
git add .github desktop/electron
git status --short --branch --ignored
git commit -m "Promote Auto Translator Native with desktop release pipeline"
```

The current user goal authorizes GitHub push, but push still requires an authenticated GitHub remote.

For the full publish sequence, see `docs/GITHUB_PUBLISH_RUNBOOK.md` or run:

```zsh
./scripts/print_github_publish_commands.sh
```

## Post-Commit Checks

After a local commit, verify:

```zsh
git status --short --branch --ignored
git remote -v
./scripts/check_repo_safety.sh
./scripts/check_first_commit_ready.sh
```

The expected post-commit shape is a clean tracked source tree, ignored local app/work outputs, and either no remote yet or the expected `ggglitter/auto-translator-native` origin.
