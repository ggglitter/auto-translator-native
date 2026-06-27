# Continue App

Use this file as the repo-local continuation entry until hidden `.agents/skills/continue-app` can be added. For the full handoff, read `docs/HANDOFF.md`.

## Resume Prompt

继续 Auto Translator Native，本地正式 repo 在 `/Users/laura/Documents/翻译软件`。先看 `git status --short --branch --ignored`、`git remote -v`、`docs/HANDOFF.md` 和相关 diff，不要覆盖用户改动。当前用户已授权 GitHub 发布、push、Windows/macOS 构建和 OTA；仍不要保存真实 API Key。下一步优先做一个小而可验证的产品/工程切片。

## Required First Checks

```zsh
git status --short --branch
git remote -v
rg -n "sk-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{20,}|Bearer [A-Za-z0-9._-]{20,}" -S . -g '!work' -g '!Auto Translator Native.app'
```

## Safe Local Verification

```zsh
./build.sh
./scripts/preflight_local.sh
./scripts/prepare_manual_smoke_bundle.sh
```

Manual API smoke tests should enter keys only through the app UI so they stay in macOS Keychain.

Manual app-window verification should follow `docs/MANUAL_SMOKE_CHECKLIST.md` and record results in `docs/MANUAL_SMOKE_FINDINGS.md`.
