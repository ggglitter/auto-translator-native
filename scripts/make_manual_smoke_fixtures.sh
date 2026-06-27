#!/bin/zsh
set -euo pipefail

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="/tmp/autotranslator-manual-smoke-$STAMP"

mkdir -p "$OUT/docx/word"

cat > "$OUT/sample.txt" <<'TXT'
Auto Translator manual smoke file.

This file is for local extraction preview testing.
No API key is required for preview.
TXT

cat > "$OUT/sample.md" <<'MD'
# Auto Translator Smoke

- Markdown structure should remain visible in preview.
- `inline code` should remain recognizable.
- Links such as https://example.com should remain intact.
MD

cat > "$OUT/docx/[Content_Types].xml" <<'XML'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
XML

cat > "$OUT/docx/word/document.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:r><w:t>Manual smoke DOCX paragraph.</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:t>Inline</w:t></w:r>
      <w:r><w:tab/></w:r>
      <w:r><w:t>tab and</w:t></w:r>
      <w:r><w:br/></w:r>
      <w:r><w:t>line break.</w:t></w:r>
    </w:p>
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Table left</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Table right</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
  </w:body>
</w:document>
XML

(
  cd "$OUT/docx"
  /usr/bin/zip -qr "$OUT/sample.docx" .
)

rm -rf "$OUT/docx"

echo "$OUT"
echo "$OUT/sample.txt"
echo "$OUT/sample.md"
echo "$OUT/sample.docx"

