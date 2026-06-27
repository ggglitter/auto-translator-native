# Signing Secrets Checklist

Last updated: 2026-06-27

This checklist records secret names only. Do not store real certificate files,
passwords, private keys, Apple credentials, GitHub tokens, or API keys in this
repo or chat.

## GitHub Secret Names

macOS certificate signing:

- `MAC_CSC_LINK`: Developer ID Application certificate as a CI-safe value, such
  as a base64-encoded `.p12` or a private download URL.
- `MAC_CSC_KEY_PASSWORD`: password for the Developer ID certificate.

macOS notarization, preferred App Store Connect API key family:

- `APPLE_API_KEY`
- `APPLE_API_KEY_ID`
- `APPLE_API_ISSUER`

macOS notarization, fallback Apple ID family:

- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`

Windows code signing:

- `WIN_CSC_LINK`: Windows signing certificate as a CI-safe value, such as a
  base64-encoded `.pfx` or a private download URL.
- `WIN_CSC_KEY_PASSWORD`: password for the Windows signing certificate.

## CI Mapping

When production signing is enabled later, map the secret values into the build
job environment only. Do not write the values into `package.json`, workflow
files, docs, shell history, or generated artifacts checked into Git.

macOS job mapping should expose the mac certificate to electron-builder as
`CSC_LINK` and `CSC_KEY_PASSWORD`, plus one notarization credential family.
The ad-hoc mac signing hook skips itself when `CSC_LINK`, `CSC_NAME`, or
`MAC_CSC_LINK` is present so a Developer ID signature is not overwritten.

Windows job mapping should expose `WIN_CSC_LINK` and
`WIN_CSC_KEY_PASSWORD`.

## Local Gate

Run:

```zsh
./scripts/check_signing_readiness.sh
```

This gate proves that the repo has the non-secret signing plan and does not
track common signing material. It does not prove that real signing credentials
exist or that notarization has passed.
