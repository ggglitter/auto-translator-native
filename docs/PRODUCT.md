# Product Notes

Auto Translator Native is a desktop translation app for local document workflows.

## User Workflow

1. Open `Auto Translator Native.app`.
2. Add files by drag-and-drop or file picker.
3. Choose OpenAI / GPT, Gemini, or dual-engine mode.
4. Save API keys to macOS Keychain through the UI.
5. Start translation and collect outputs from `~/Downloads/AutoTranslatorOutput`.

## Current Capabilities

- Text-like formats are read directly.
- PDF uses `PDFKit` text extraction.
- DOCX extracts `word/document.xml` through `/usr/bin/unzip` and parses text nodes.
- Large text is split into chunks before API calls.
- Gemini can be used for draft translation and OpenAI for polishing.
- The existing SwiftUI source is the local macOS-native implementation.
- `desktop/electron/` is the cross-platform Windows/macOS release track with Electron, `electron-builder`, and `electron-updater`.
- The Electron release track includes in-app OTA controls for checking, downloading, and installing updates.

## Release Goals

- Source code should be hosted on GitHub.
- GitHub Actions should build Windows and macOS installers.
- OTA should use GitHub Release metadata for the Electron release track.
- Real API keys must only be saved through the app UI into local OS-backed storage, never in repo files.
