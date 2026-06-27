# Manual Smoke Checklist

This checklist verifies the app window and local file workflows without committing secrets.

## Prepare Fixtures

Run the local preflight first:

```zsh
./scripts/preflight_local.sh
```

For a Finder-friendly manual bundle, run:

```zsh
./scripts/prepare_manual_smoke_bundle.sh
```

To re-verify an existing manual bundle before opening it, run:

```zsh
./scripts/verify_manual_smoke_bundle.sh /tmp/autotranslator-manual-bundle-20260627-112011
```

Run:

```zsh
./scripts/make_manual_smoke_fixtures.sh
```

The script prints a temporary directory under `/tmp` with:

- `sample.txt`
- `sample.md`
- `sample.docx`

These files contain no secrets and are safe to drag into the app.

## No-Key Checks

1. Run `./build.sh`.
2. Run `./scripts/smoke_launch_app.sh`. If the script reports `launch_smoke_open_skipped`, continue with the manual `open` step and record the result.
3. Open the app with `open "Auto Translator Native.app"`.
4. Click `添加文件` or drag the generated sample files into the drop area.
5. Verify the file list shows all selected files and file sizes.
6. Select a file row and click `预览抽取`.
7. Verify TXT and Markdown previews show readable text.
8. Verify DOCX preview preserves paragraph text, inline tab/line break text, and the table row.
9. Clear the file list and verify previous per-file results disappear.
10. Click `开始翻译` with missing keys and verify the app reports the missing required key instead of starting a network request.

## Optional API Checks

Only use real API keys through the app UI so they stay in macOS Keychain.

1. Enter the provider key in the secure field.
2. Click `保存 Key 到钥匙串`.
3. Add only a tiny TXT fixture.
4. Set `分段字符上限` and `失败重试次数` to the desired local values.
5. Start translation.
6. Verify the file row shows active progress, then `已保存`.
7. Click the output-file icon and confirm Finder selects the translated file.

Do not paste real API keys into repository files, docs, scripts, terminal logs, or chat.

Record results in `docs/MANUAL_SMOKE_FINDINGS.md`.
