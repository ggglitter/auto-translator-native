#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}/.."
TMP="$(mktemp -d /tmp/autotranslator-extract-smoke.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/fixtures/docx/word"

cat > "$TMP/fixtures/sample.txt" <<'TXT'
Hello Auto Translator.
Second line for extraction.
TXT

cat > "$TMP/fixtures/docx/[Content_Types].xml" <<'XML'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
XML

cat > "$TMP/fixtures/docx/word/document.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:r><w:t>First DOCX paragraph.</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:t>Second DOCX paragraph.</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:t>Inline</w:t></w:r>
      <w:r><w:tab/></w:r>
      <w:r><w:t>Tab</w:t></w:r>
      <w:r><w:br/></w:r>
      <w:r><w:t>Break</w:t></w:r>
    </w:p>
    <w:tbl>
      <w:tr>
        <w:tc>
          <w:p><w:r><w:t>Left cell</w:t></w:r></w:p>
        </w:tc>
        <w:tc>
          <w:p><w:r><w:t>Right cell</w:t></w:r></w:p>
        </w:tc>
      </w:tr>
    </w:tbl>
  </w:body>
</w:document>
XML

(
  cd "$TMP/fixtures/docx"
  /usr/bin/zip -qr "$TMP/fixtures/sample.docx" .
)

cat > "$TMP/main.swift" <<'SWIFT'
import Foundation

let fixtureRoot = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("smoke_extract_failed: \(message)\n", stderr)
        exit(1)
    }
}

let text = try FileTextExtractor.read(url: fixtureRoot.appendingPathComponent("sample.txt"))
require(text.contains("Hello Auto Translator."), "txt extraction missed first line")
require(text.contains("Second line for extraction."), "txt extraction missed second line")

let docx = try FileTextExtractor.read(url: fixtureRoot.appendingPathComponent("sample.docx"))
require(docx.contains("First DOCX paragraph."), "docx extraction missed first paragraph")
require(docx.contains("Second DOCX paragraph."), "docx extraction missed second paragraph")
require(docx.contains("Inline\tTab\nBreak"), "docx extraction missed inline tab or break")
require(docx.contains("Left cell\tRight cell"), "docx extraction missed table row cells")

let chunks = TextChunker.split("Alpha\n\nBeta\n\nGamma", maxCharacters: 8)
require(chunks.count >= 3, "chunker did not split a small maxCharacters fixture")
require(chunks.first == "Alpha", "chunker did not preserve first block")

print("smoke_extract_ok")
SWIFT

swiftc \
  -module-cache-path "$TMP/module-cache" \
  "$ROOT/Sources/TextProcessing.swift" \
  "$TMP/main.swift" \
  -o "$TMP/smoke_extract" \
  -framework PDFKit

"$TMP/smoke_extract" "$TMP/fixtures"
