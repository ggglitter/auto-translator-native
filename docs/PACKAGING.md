# Local Packaging

Local packaging creates a zip artifact for manual transfer or desktop testing. It does not create GitHub releases, upload files, or store API keys.

Run:

```zsh
./scripts/package_local_app.sh
```

The script:

- rebuilds `Auto Translator Native.app`
- writes a zip under `/tmp/autotranslator-packages-*`
- writes a `.sha256` checksum next to the zip
- verifies the checksum with `shasum -c`
- verifies the zip structure with `unzip -t`
- writes a local `manifest.json` with package metadata and verification results
- verifies the manifest with `./scripts/verify_local_package.sh`

To re-verify an existing package:

```zsh
./scripts/verify_local_package.sh /tmp/autotranslator-packages-*/manifest.json
```

You can also pass a package directory:

```zsh
./scripts/verify_local_package.sh /tmp/autotranslator-packages-20260627-111622
```

The generated package is a local, ad-hoc signed development artifact. It is not notarized.

Latest verified local package:

- `/tmp/autotranslator-packages-20260627-111622/AutoTranslatorNative-1.0.0-20260627-111622.zip`
- `/tmp/autotranslator-packages-20260627-111622/AutoTranslatorNative-1.0.0-20260627-111622.zip.sha256`
- `/tmp/autotranslator-packages-20260627-111622/manifest.json`

Verification passed with `shasum -c`, `unzip -t`, `python3 -m json.tool`, and `./scripts/verify_local_package.sh`.

For manual product checks, also run:

```zsh
./scripts/prepare_manual_smoke_bundle.sh
```

That bundle includes the app, disposable fixture files, and a local `README.txt`.
