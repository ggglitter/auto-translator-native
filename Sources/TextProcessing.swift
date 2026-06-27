import Foundation
import PDFKit

enum AppError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            return message
        }
    }
}

enum FileTextExtractor {
    private static let textExtensions: Set<String> = [
        "txt", "md", "markdown", "csv", "tsv", "json", "jsonl",
        "yaml", "yml", "html", "htm", "xml", "srt", "vtt", "po", "ini", "log"
    ]

    static func read(url: URL) throws -> String {
        let ext = url.pathExtension.lowercased()
        if textExtensions.contains(ext) || ext.isEmpty {
            return try readPlainText(url: url)
        }
        if ext == "pdf" {
            return try readPDF(url: url)
        }
        if ext == "docx" {
            return try readDOCX(url: url)
        }
        throw AppError.message("暂不支持 .\(ext) 文件。")
    }

    private static func readPlainText(url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let encodings: [String.Encoding] = [.utf8, .utf16, .isoLatin1]
        for encoding in encodings {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static func readPDF(url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw AppError.message("PDF 读取失败。")
        }
        let text = document.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            throw AppError.message("PDF 没有抽取到文字，可能是扫描件。")
        }
        return text
    }

    private static func readDOCX(url: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", url.path, "word/document.xml"]

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let detail = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw AppError.message("DOCX 读取失败：\(detail)")
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let parser = DOCXTextParser()
        let text = try parser.extract(from: data).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw AppError.message("DOCX 没有抽取到文字。")
        }
        return text
    }
}

final class DOCXTextParser: NSObject, XMLParserDelegate {
    private var paragraphs: [String] = []
    private var currentParagraph = ""
    private var currentCellParagraphs: [String] = []
    private var currentRowCells: [String] = []
    private var isInsideText = false
    private var isInsideTableCell = false
    private var isInsideTableRow = false

    func extract(from data: Data) throws -> String {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw AppError.message("DOCX XML 解析失败。")
        }
        flushParagraph()
        flushTableRow()
        return paragraphs.joined(separator: "\n\n")
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let name = normalized(elementName, qName)
        switch name {
        case "t":
            isInsideText = true
        case "tab":
            currentParagraph += "\t"
        case "br", "cr":
            currentParagraph += "\n"
        case "tr":
            isInsideTableRow = true
            currentRowCells = []
        case "tc":
            isInsideTableCell = true
            currentCellParagraphs = []
            currentParagraph = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInsideText {
            currentParagraph += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = normalized(elementName, qName)
        switch name {
        case "t":
            isInsideText = false
        case "p":
            flushParagraph()
        case "tc":
            flushParagraph()
            flushTableCell()
        case "tr":
            flushTableRow()
        default:
            break
        }
    }

    private func flushParagraph() {
        let text = currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            if isInsideTableCell {
                currentCellParagraphs.append(text)
            } else {
                paragraphs.append(text)
            }
        }
        currentParagraph = ""
    }

    private func flushTableCell() {
        let text = currentCellParagraphs
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            currentRowCells.append(text)
        }
        currentCellParagraphs = []
        isInsideTableCell = false
    }

    private func flushTableRow() {
        guard isInsideTableRow || !currentRowCells.isEmpty else {
            return
        }

        let text = currentRowCells
            .joined(separator: "\t")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            paragraphs.append(text)
        }
        currentRowCells = []
        isInsideTableRow = false
    }

    private func normalized(_ elementName: String, _ qualifiedName: String?) -> String {
        let raw = qualifiedName ?? elementName
        return raw.split(separator: ":").last.map(String.init) ?? raw
    }
}

enum TextChunker {
    static func split(_ text: String, maxCharacters: Int = 3500) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard trimmed.count > maxCharacters else { return [trimmed] }

        var chunks: [String] = []
        var current = ""

        for block in trimmed.components(separatedBy: "\n\n") {
            let piece = block + "\n\n"
            if piece.count > maxCharacters {
                if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    chunks.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                    current = ""
                }
                chunks.append(contentsOf: hardSplit(piece, maxCharacters: maxCharacters))
            } else if current.count + piece.count > maxCharacters {
                chunks.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = piece
            } else {
                current += piece
            }
        }

        let final = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !final.isEmpty {
            chunks.append(final)
        }
        return chunks
    }

    private static func hardSplit(_ text: String, maxCharacters: Int) -> [String] {
        var result: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: maxCharacters, limitedBy: text.endIndex) ?? text.endIndex
            result.append(String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines))
            start = end
        }
        return result.filter { !$0.isEmpty }
    }
}
