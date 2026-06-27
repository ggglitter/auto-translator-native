# Roadmap

## Next Small Slices

- Download Actions or Release artifacts and run `./scripts/check_release_artifacts.sh`.
- For the next macOS release, enforce universal mac artifacts with `./scripts/check_release_artifacts.sh --platform mac --mac-arch universal`.
- Configure signing/notarization secrets before claiming production macOS OTA.
- Perform manual app-window pass and record real findings.

## Completed Local Slices

- Add a dry-run extraction preview before API translation.
- Add clearer per-file progress and per-file output links.
- Add a local smoke-test fixture set that does not require real API keys.
- Add better DOCX paragraph and table extraction.
- Add configurable chunk size and retry behavior.
- Add a local manual smoke checklist for the app window.
- Add selectable file rows so extraction preview targets the selected file.
- Add local preflight and manual smoke findings record.
- Add automatic app launch smoke before manual window checks.
- Add Finder-friendly manual smoke bundle preparation.
- Add local zip packaging script with checksum.
- Add non-hidden repo-local handoff after hidden `.agents` and `.codex` writes were blocked.
- Add local repo safety gate for remote/ignored-output/real-secret checks.
- Add first local commit plan without staging or committing.
- Add first commit readiness check without staging files.
- Harden secret-scan scripts so missing `rg` fails instead of passing.
- Fold first-commit readiness into full local preflight.
- Add local package manifest with checksum and zip verification results.
- Add local package verifier for manifest/checksum/zip consistency.
- Add manual smoke bundle verifier for app/fixture integrity.
- Add cross-platform Electron release track for Windows/macOS packaging and OTA metadata.
- Add GitHub Actions desktop release workflow.
- Add GitHub publish runbook and command printer.
- Add Electron OTA check/download/install controls.
- Record completed local first commit, tag, and HTTPS remote state.
- Add release artifact acceptance checker and artifact checklist.
- Add signing/notarization plan without secrets.
- Add final release gate for clean tree, version consistency, tag alignment, and origin validation.
- Publish `main` and `v1.0.0` to GitHub and verify release assets.
- Add universal mac release build command and CI artifact naming.

## Later

- Package a notarized macOS build.
- Complete signing and notarization for user-facing OTA.
- Decide whether OTA remains on public GitHub Releases or moves to a separate HTTPS update host.
- Add export formats beyond plain translated text for DOCX/PDF inputs.
