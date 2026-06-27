import SwiftUI
import AppKit
import Foundation
import PDFKit
import Security
import UniformTypeIdentifiers

enum TranslationProvider: String, CaseIterable, Identifiable {
    case openai
    case gemini
    case dual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openai: return "OpenAI / GPT"
        case .gemini: return "Gemini"
        case .dual: return "双引擎"
        }
    }

    var subtitle: String {
        switch self {
        case .openai: return "只用 OpenAI 翻译"
        case .gemini: return "只用 Gemini 翻译"
        case .dual: return "Gemini 初译 + OpenAI 润色"
        }
    }

    var needsOpenAI: Bool { self == .openai || self == .dual }
    var needsGemini: Bool { self == .gemini || self == .dual }
}

struct InputFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL

    var name: String { url.lastPathComponent }

    var displaySize: String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values?.fileSize else { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

struct FileTranslationResult {
    let outputURL: URL?
    let errorMessage: String?
}

enum KeychainStore {
    private static let service = "Auto Translator Native"

    static func read(account: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func save(_ value: String, account: String) {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(baseQuery as CFDictionary)

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            return
        }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}

@main
struct AutoTranslatorNativeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct ContentView: View {
    @State private var files: [InputFile] = []
    @State private var provider: TranslationProvider = .dual
    @State private var sourceLanguage = "自动识别"
    @State private var targetLanguage = "中文（简体）"
    @State private var tone = "自然、准确、适合正式阅读"
    @State private var openAIKey: String
    @State private var geminiKey: String
    @State private var isDropTargeted = false
    @State private var isTranslating = false
    @State private var progress = 0.0
    @State private var status = "准备好了。把文件拖进来，或者点“添加文件”。"
    @State private var previewTitle = ""
    @State private var previewText = ""
    @State private var isPreviewPresented = false
    @State private var activeFileID: UUID?
    @State private var selectedFileID: UUID?
    @State private var fileResults: [UUID: FileTranslationResult] = [:]

    @AppStorage("openaiModel") private var openAIModel = "gpt-4o-mini"
    @AppStorage("geminiModel") private var geminiModel = "gemini-2.0-flash"
    @AppStorage("maxChunkCharacters") private var maxChunkCharacters = 3500
    @AppStorage("apiRetryCount") private var apiRetryCount = 1

    private var outputFolder: URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        return downloads.appendingPathComponent("AutoTranslatorOutput", isDirectory: true)
    }

    init() {
        _openAIKey = State(initialValue: KeychainStore.read(account: "openai"))
        _geminiKey = State(initialValue: KeychainStore.read(account: "gemini"))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.13),
                    Color(red: 0.10, green: 0.05, blue: 0.18),
                    Color(red: 0.04, green: 0.12, blue: 0.17)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                header

                HStack(alignment: .top, spacing: 18) {
                    dropCard
                    settingsCard
                }

                fileListCard
                footerBar
            }
            .padding(24)
        }
        .frame(minWidth: 1040, minHeight: 760)
        .sheet(isPresented: $isPreviewPresented) {
            ExtractionPreviewSheet(title: previewTitle, text: previewText)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Auto Translator")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("拖入文件，选择 OpenAI / Gemini / 双引擎，译文默认保存到 Downloads。")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer()

            Button {
                openOutputFolder()
            } label: {
                Label("打开输出文件夹", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
        }
    }

    private var dropCard: some View {
        Card {
            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(isDropTargeted ? Color.cyan.opacity(0.18) : Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(
                                    isDropTargeted ? Color.cyan.opacity(0.95) : Color.white.opacity(0.18),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [9, 7])
                                )
                        )

                    VStack(spacing: 12) {
                        Image(systemName: "doc.badge.arrow.up")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(.cyan)

                        Text("拖拽文件到这里")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("支持 txt、md、csv、json、html、srt、pdf、docx。PDF / DOCX 会抽取文字输出译文文本。")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.62))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)

                        Button {
                            addFiles()
                        } label: {
                            Label("添加文件", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(24)
                }
                .frame(minHeight: 260)
                .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
                    handleDrop(providers)
                }

                HStack {
                    Label("输出目录", systemImage: "arrow.down.doc")
                        .foregroundStyle(.white.opacity(0.72))
                    Spacer()
                    Text(outputFolder.path)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private var settingsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("翻译设置")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Picker("引擎", selection: $provider) {
                    ForEach(TranslationProvider.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                Text(provider.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.56))

                Group {
                    labeledTextField("源语言", text: $sourceLanguage)
                    labeledTextField("目标语言", text: $targetLanguage)
                    labeledTextField("风格", text: $tone)
                }

                Divider().overlay(Color.white.opacity(0.14))

                Text("API Keys")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                SecureField("OpenAI / GPT API Key", text: $openAIKey)
                    .textFieldStyle(.roundedBorder)

                SecureField("Gemini API Key", text: $geminiKey)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    TextField("OpenAI Model", text: $openAIModel)
                        .textFieldStyle(.roundedBorder)
                    TextField("Gemini Model", text: $geminiModel)
                        .textFieldStyle(.roundedBorder)
                }

                Divider().overlay(Color.white.opacity(0.14))

                Text("请求设置")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                numericStepper(
                    "分段字符上限",
                    value: $maxChunkCharacters,
                    range: 1000...12000,
                    step: 500,
                    suffix: "字符"
                )

                numericStepper(
                    "失败重试次数",
                    value: $apiRetryCount,
                    range: 0...5,
                    step: 1,
                    suffix: "次"
                )

                Button {
                    saveKeys()
                    status = "API Key 已保存到 macOS 钥匙串。"
                } label: {
                    Label("保存 Key 到钥匙串", systemImage: "key")
                }
                .buttonStyle(.bordered)
                .tint(.cyan)
            }
            .frame(width: 360)
        }
    }

    private var fileListCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("文件列表")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(files.count) 个文件")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Button("清空") {
                        files.removeAll()
                        fileResults.removeAll()
                        activeFileID = nil
                        selectedFileID = nil
                    }
                    .disabled(files.isEmpty || isTranslating)
                }

                if files.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 28))
                                .foregroundStyle(.white.opacity(0.38))
                            Text("还没有文件")
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .padding(.vertical, 34)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(files) { file in
                                fileRow(file)
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
            }
        }
    }

    private var footerBar: some View {
        Card {
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    Button {
                        Task { await translateAll() }
                    } label: {
                        Label(isTranslating ? "翻译中" : "开始翻译", systemImage: "sparkles")
                            .frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(files.isEmpty || isTranslating)

                    Button {
                        previewExtraction()
                    } label: {
                        Label("预览抽取", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .disabled(files.isEmpty || isTranslating)

                    Button {
                        openOutputFolder()
                    } label: {
                        Label("打开 Downloads 输出", systemImage: "folder.badge.gearshape")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Text(status)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }

                if isTranslating {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                }
            }
        }
    }

    private func labeledTextField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func numericStepper(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))

            Stepper(value: value, in: range, step: step) {
                Text("\(value.wrappedValue) \(suffix)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
    }

    private func fileRow(_ file: InputFile) -> some View {
        let result = fileResults[file.id]
        let isActive = activeFileID == file.id
        let isSelected = selectedFileID == file.id

        return HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .foregroundStyle(isSelected ? .white : .cyan)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(file.url.path)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if isActive {
                    Text("正在翻译...")
                        .font(.system(size: 11))
                        .foregroundStyle(.cyan.opacity(0.85))
                } else if let outputURL = result?.outputURL {
                    Text("已保存：\(outputURL.lastPathComponent)")
                        .font(.system(size: 11))
                        .foregroundStyle(.green.opacity(0.82))
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if let errorMessage = result?.errorMessage {
                    Text("失败：\(errorMessage)")
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.82))
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else if isSelected {
                    Text("已选择，可预览抽取")
                        .font(.system(size: 11))
                        .foregroundStyle(.cyan.opacity(0.85))
                }
            }
            Spacer()
            if isActive {
                ProgressView()
                    .controlSize(.small)
            }
            if let outputURL = result?.outputURL {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.green.opacity(0.88))
                .help("打开译文文件")
            }
            Text(file.displaySize)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.50))
            Button {
                let removedSelectedFile = selectedFileID == file.id
                files.removeAll { $0.id == file.id }
                fileResults[file.id] = nil
                if removedSelectedFile {
                    selectedFileID = files.first?.id
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.42))
            .disabled(isTranslating)
        }
        .padding(10)
        .background(
            isSelected ? Color.cyan.opacity(0.16) : Color.white.opacity(0.055),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.cyan.opacity(0.82) : Color.clear, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            selectedFileID = file.id
        }
    }

    private func addFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.title = "选择要翻译的文件"
        if panel.runModal() == .OK {
            appendURLs(panel.urls)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                var droppedURL: URL?
                if let data = item as? Data {
                    droppedURL = URL(dataRepresentation: data, relativeTo: nil)
                } else if let string = item as? String {
                    droppedURL = URL(string: string)
                }

                if let droppedURL {
                    DispatchQueue.main.async {
                        appendURLs([droppedURL])
                    }
                }
            }
        }
        return true
    }

    private func appendURLs(_ urls: [URL]) {
        var added = false
        for url in urls {
            guard !files.contains(where: { $0.url == url }) else { continue }
            let file = InputFile(url: url)
            files.append(file)
            if selectedFileID == nil {
                selectedFileID = file.id
            }
            added = true
        }
        status = added ? "已添加 \(files.count) 个文件。" : "文件已在列表中。"
    }

    private func saveKeys() {
        KeychainStore.save(openAIKey, account: "openai")
        KeychainStore.save(geminiKey, account: "gemini")
    }

    private func previewExtraction() {
        let targetFile = selectedFileID.flatMap { id in
            files.first { $0.id == id }
        } ?? files.first

        guard let file = targetFile else {
            status = "先添加要预览的文件。"
            return
        }

        do {
            let extracted = try FileTextExtractor.read(url: file.url).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !extracted.isEmpty else {
                throw AppError.message("文件没有可预览文字。")
            }

            let maxPreviewCharacters = 12000
            let preview: String
            if extracted.count > maxPreviewCharacters {
                preview = String(extracted.prefix(maxPreviewCharacters)) + "\n\n...仅预览前 \(maxPreviewCharacters) 个字符"
            } else {
                preview = extracted
            }

            previewTitle = "\(file.name) · \(extracted.count) 字符"
            previewText = preview
            isPreviewPresented = true
            status = "已生成 \(file.name) 的抽取预览。"
        } catch {
            status = "预览失败：\(error.localizedDescription)"
        }
    }

    @MainActor
    private func translateAll() async {
        saveKeys()

        if provider.needsOpenAI && openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            status = "缺少 OpenAI / GPT API Key。"
            return
        }
        if provider.needsGemini && geminiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            status = "缺少 Gemini API Key。"
            return
        }

        isTranslating = true
        progress = 0

        let service = TranslatorService(
            provider: provider,
            openAIKey: openAIKey,
            geminiKey: geminiKey,
            openAIModel: openAIModel,
            geminiModel: geminiModel,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            tone: tone,
            maxChunkCharacters: maxChunkCharacters,
            retryCount: apiRetryCount,
            outputFolder: outputFolder
        )

        var completed = 0
        var failures: [String] = []

        for (index, file) in files.enumerated() {
            activeFileID = file.id
            fileResults[file.id] = nil
            status = "正在翻译：\(file.name)"
            do {
                let outputURL = try await service.translateFile(file.url)
                fileResults[file.id] = FileTranslationResult(outputURL: outputURL, errorMessage: nil)
                completed += 1
            } catch {
                fileResults[file.id] = FileTranslationResult(outputURL: nil, errorMessage: error.localizedDescription)
                failures.append("\(file.name)：\(error.localizedDescription)")
            }
            progress = Double(index + 1) / Double(max(files.count, 1))
        }

        activeFileID = nil
        isTranslating = false
        if failures.isEmpty {
            status = "完成：\(completed) 个文件已保存到 \(outputFolder.path)"
            openOutputFolder()
        } else {
            status = "完成 \(completed) 个，失败 \(failures.count) 个。第一条错误：\(failures.first ?? "")"
        }
    }

    private func openOutputFolder() {
        try? FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(outputFolder)
    }
}

struct ExtractionPreviewSheet: View {
    let title: String
    let text: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("抽取预览")
                        .font(.system(size: 18, weight: .semibold))
                    Text(title)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("关闭")
            }
            .padding(16)

            Divider()

            ScrollView {
                Text(text)
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(minWidth: 720, minHeight: 520)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

struct TranslatorService {
    let provider: TranslationProvider
    let openAIKey: String
    let geminiKey: String
    let openAIModel: String
    let geminiModel: String
    let sourceLanguage: String
    let targetLanguage: String
    let tone: String
    let maxChunkCharacters: Int
    let retryCount: Int
    let outputFolder: URL

    func translateFile(_ url: URL) async throws -> URL {
        let text = try FileTextExtractor.read(url: url)
        let chunks = TextChunker.split(text, maxCharacters: maxChunkCharacters)
        guard !chunks.isEmpty else {
            throw AppError.message("文件没有可翻译文字。")
        }

        var translatedChunks: [String] = []
        for (index, chunk) in chunks.enumerated() {
            let chunkName = chunks.count == 1 ? url.lastPathComponent : "\(url.lastPathComponent) 第 \(index + 1)/\(chunks.count) 段"
            let translated = try await translateChunk(chunk, filename: chunkName)
            translatedChunks.append(translated)
        }

        let translatedText = translatedChunks.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)

        let outputURL = uniqueOutputURL(for: url)
        try translatedText.write(to: outputURL, atomically: true, encoding: .utf8)
        return outputURL
    }

    private func translateChunk(_ text: String, filename: String) async throws -> String {
        let prompt = PromptBuilder.userPrompt(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            tone: tone,
            filename: filename
        )

        switch provider {
        case .openai:
            return try await translateWithOpenAI(prompt)
        case .gemini:
            return try await translateWithGemini(prompt)
        case .dual:
            let draft = try await translateWithGemini(prompt)
            let polishPrompt = PromptBuilder.polishPrompt(
                sourceText: text,
                draftText: draft,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                tone: tone,
                filename: filename
            )
            return try await translateWithOpenAI(polishPrompt)
        }
    }

    private func translateWithOpenAI(_ prompt: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw AppError.message("OpenAI URL 无效。")
        }

        let body: [String: Any] = [
            "model": openAIModel,
            "input": [
                ["role": "system", "content": PromptBuilder.systemPrompt],
                ["role": "user", "content": prompt]
            ]
        ]

        let json = try await APIClient.postJSON(
            url: url,
            body: body,
            headers: [
                "Authorization": "Bearer \(openAIKey.trimmingCharacters(in: .whitespacesAndNewlines))",
                "Content-Type": "application/json"
            ],
            retryCount: retryCount
        )

        if let outputText = json["output_text"] as? String, !outputText.isEmpty {
            return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var texts: [String] = []
        if let output = json["output"] as? [[String: Any]] {
            for item in output {
                if let content = item["content"] as? [[String: Any]] {
                    for block in content {
                        if let text = block["text"] as? String {
                            texts.append(text)
                        }
                    }
                }
            }
        }

        let result = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else {
            throw AppError.message("OpenAI 返回里没有找到译文。")
        }
        return result
    }

    private func translateWithGemini(_ prompt: String) async throws -> String {
        let model = geminiModel.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? geminiModel
        let key = geminiKey.trimmingCharacters(in: .whitespacesAndNewlines).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? geminiKey
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)") else {
            throw AppError.message("Gemini URL 无效。")
        }

        let body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": "\(PromptBuilder.systemPrompt)\n\n\(prompt)"]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2
            ]
        ]

        let json = try await APIClient.postJSON(
            url: url,
            body: body,
            headers: ["Content-Type": "application/json"],
            retryCount: retryCount
        )

        var texts: [String] = []
        if let candidates = json["candidates"] as? [[String: Any]] {
            for candidate in candidates {
                if let content = candidate["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]] {
                    for part in parts {
                        if let text = part["text"] as? String {
                            texts.append(text)
                        }
                    }
                }
            }
        }

        let result = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else {
            throw AppError.message("Gemini 返回里没有找到译文。")
        }
        return result
    }

    private func uniqueOutputURL(for inputURL: URL) -> URL {
        let originalExtension = inputURL.pathExtension.lowercased()
        let outputExtension = ["pdf", "docx"].contains(originalExtension) ? "txt" : (originalExtension.isEmpty ? "txt" : originalExtension)
        let safeBase = inputURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        var candidate = outputFolder.appendingPathComponent("\(safeBase).translated.\(outputExtension)")
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = outputFolder.appendingPathComponent("\(safeBase).translated-\(index).\(outputExtension)")
            index += 1
        }
        return candidate
    }
}

enum APIClient {
    static func postJSON(url: URL, body: [String: Any], headers: [String: String], retryCount: Int = 0) async throws -> [String: Any] {
        let attempts = max(0, retryCount) + 1
        var lastError: Error?

        for attempt in 0..<attempts {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw AppError.message("API 没有返回 HTTP 响应。")
                }

                guard (200..<300).contains(http.statusCode) else {
                    let detail = String(data: data, encoding: .utf8) ?? "无错误详情"
                    if isRetryableStatus(http.statusCode), attempt < attempts - 1 {
                        try await waitBeforeRetry(attempt: attempt)
                        continue
                    }
                    throw AppError.message("API 请求失败 HTTP \(http.statusCode)：\(detail.prefix(800))")
                }

                let object = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = object as? [String: Any] else {
                    throw AppError.message("API 返回不是 JSON 对象。")
                }
                return json
            } catch {
                lastError = error
                if isRetryableError(error), attempt < attempts - 1 {
                    try await waitBeforeRetry(attempt: attempt)
                    continue
                }
                throw error
            }
        }

        throw lastError ?? AppError.message("API 请求失败。")
    }

    private static func isRetryableStatus(_ statusCode: Int) -> Bool {
        statusCode == 408 || statusCode == 429 || (500..<600).contains(statusCode)
    }

    private static func isRetryableError(_ error: Error) -> Bool {
        error is URLError
    }

    private static func waitBeforeRetry(attempt: Int) async throws {
        let delay = UInt64(min(4, attempt + 1)) * 500_000_000
        try await Task.sleep(nanoseconds: delay)
    }
}

enum PromptBuilder {
    static let systemPrompt = """
    你是一名专业翻译和本地化编辑。

    请严格遵守：
    1. 只输出译文，不要解释、不要寒暄、不要添加标题。
    2. 保留原文的 Markdown、HTML、JSON、YAML、CSV、SRT/VTT 字幕时间轴、编号、URL、邮箱、代码块、占位符和变量名。
    3. 不要翻译代码、命令、文件路径、API 参数、花括号/尖括号占位符。
    4. 如果原文中有术语不确定，优先保持一致、自然、可读。
    5. 如果原文已经接近目标语言，请润色为自然的目标语言表达。
    """

    static func userPrompt(text: String, sourceLanguage: String, targetLanguage: String, tone: String, filename: String) -> String {
        """
        文件名：\(filename)
        源语言：\(sourceLanguage)
        目标语言：\(targetLanguage)
        风格要求：\(tone)

        请翻译下面这段内容：

        <content>
        \(text)
        </content>
        """
    }

    static func polishPrompt(sourceText: String, draftText: String, sourceLanguage: String, targetLanguage: String, tone: String, filename: String) -> String {
        """
        文件名：\(filename)
        源语言：\(sourceLanguage)
        目标语言：\(targetLanguage)
        风格要求：\(tone)

        下面有原文和一版 Gemini 初译。请根据原文校对、修正误译、补足遗漏并润色成最终译文。
        只输出最终译文，不要解释。

        <source>
        \(sourceText)
        </source>

        <draft>
        \(draftText)
        </draft>
        """
    }
}
