const { app, BrowserWindow, dialog, ipcMain, shell, safeStorage } = require("electron");
const { autoUpdater } = require("electron-updater");
const fs = require("fs/promises");
const path = require("path");
const mammoth = require("mammoth");
const pdfParse = require("pdf-parse");

const textExtensions = new Set([
  ".txt", ".md", ".markdown", ".csv", ".tsv", ".json", ".jsonl",
  ".yaml", ".yml", ".html", ".htm", ".xml", ".srt", ".vtt", ".po",
  ".ini", ".log"
]);

const keyFileName = "api-keys.enc";
let mainWindow;
let updateState = {
  status: "idle",
  message: "未检查更新。"
};

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1180,
    height: 780,
    minWidth: 980,
    minHeight: 680,
    title: "Auto Translator Native",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  mainWindow.loadFile(path.join(__dirname, "renderer", "index.html"));
}

app.whenReady().then(() => {
  createWindow();
  setupUpdater();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});

function setupUpdater() {
  autoUpdater.autoDownload = false;
  autoUpdater.on("checking-for-update", () => publishUpdateState("checking", "正在检查更新..."));
  autoUpdater.on("update-available", (info) => publishUpdateState("available", `发现新版本 ${info.version}。`));
  autoUpdater.on("update-not-available", () => publishUpdateState("idle", "当前已是最新版本。"));
  autoUpdater.on("download-progress", (progress) => {
    publishUpdateState("downloading", `正在下载更新 ${Math.round(progress.percent)}%...`);
  });
  autoUpdater.on("update-downloaded", () => publishUpdateState("downloaded", "更新已下载，重启后安装。"));
  autoUpdater.on("error", (error) => publishUpdateState("error", `更新检查失败：${error.message}`));
}

function publishUpdateState(status, message) {
  updateState = { status, message };
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send("updates:state", updateState);
  }
}

ipcMain.handle("app:get-state", async () => ({
  version: app.getVersion(),
  platform: process.platform,
  outputDir: outputDir(),
  updates: updateState
}));

ipcMain.handle("files:pick", async () => {
  const result = await dialog.showOpenDialog(mainWindow, {
    title: "选择要翻译的文件",
    properties: ["openFile", "multiSelections"],
    filters: [
      { name: "Documents", extensions: ["txt", "md", "csv", "json", "html", "srt", "pdf", "docx"] },
      { name: "All Files", extensions: ["*"] }
    ]
  });

  if (result.canceled) {
    return [];
  }
  return describeFiles(result.filePaths);
});

ipcMain.handle("files:describe", async (_event, filePaths) => describeFiles(filePaths));

ipcMain.handle("files:preview", async (_event, filePath) => {
  const text = (await extractText(filePath)).trim();
  if (!text) {
    throw new Error("文件没有可预览文字。");
  }
  return {
    title: `${path.basename(filePath)} · ${text.length} 字符`,
    text: text.length > 12000 ? `${text.slice(0, 12000)}\n\n...仅预览前 12000 个字符` : text
  };
});

ipcMain.handle("keys:load", async () => loadKeys());
ipcMain.handle("keys:save", async (_event, keys) => {
  await saveKeys(keys);
  return { ok: true };
});

ipcMain.handle("translate:start", async (_event, request) => translateFiles(request));

ipcMain.handle("shell:open-path", async (_event, targetPath) => {
  if (!targetPath) {
    return;
  }
  await shell.openPath(targetPath);
});

ipcMain.handle("updates:check", async () => {
  if (!app.isPackaged) {
    publishUpdateState("idle", "开发模式不检查 OTA。打包版本会从 GitHub Release 检查更新。");
    return updateState;
  }
  await autoUpdater.checkForUpdates();
  return updateState;
});

ipcMain.handle("updates:download", async () => {
  await autoUpdater.downloadUpdate();
  return updateState;
});

ipcMain.handle("updates:install", async () => {
  autoUpdater.quitAndInstall(false, true);
});

async function describeFiles(filePaths) {
  const rows = [];
  for (const filePath of filePaths) {
    const stat = await fs.stat(filePath);
    if (!stat.isFile()) {
      continue;
    }
    rows.push({
      path: filePath,
      name: path.basename(filePath),
      size: stat.size
    });
  }
  return rows;
}

async function extractText(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  if (textExtensions.has(ext) || ext === "") {
    const buffer = await fs.readFile(filePath);
    return decodeText(buffer);
  }
  if (ext === ".docx") {
    const result = await mammoth.extractRawText({ path: filePath });
    return result.value;
  }
  if (ext === ".pdf") {
    const buffer = await fs.readFile(filePath);
    const result = await pdfParse(buffer);
    return result.text;
  }
  throw new Error(`暂不支持 ${ext || "该"} 文件。`);
}

function decodeText(buffer) {
  const utf8 = buffer.toString("utf8");
  if (!utf8.includes("\uFFFD")) {
    return utf8;
  }
  return buffer.toString("latin1");
}

async function translateFiles(request) {
  const keys = await loadKeys();
  const provider = request.provider || "dual";
  if ((provider === "openai" || provider === "dual") && !keys.openai) {
    throw new Error("缺少 OpenAI / GPT API Key。请先保存到本机加密存储。");
  }
  if ((provider === "gemini" || provider === "dual") && !keys.gemini) {
    throw new Error("缺少 Gemini API Key。请先保存到本机加密存储。");
  }

  await fs.mkdir(outputDir(), { recursive: true });
  const results = [];
  for (const filePath of request.files || []) {
    const source = await extractText(filePath);
    const chunks = splitChunks(source, Number(request.maxChunkCharacters || 3500));
    if (chunks.length === 0) {
      throw new Error(`${path.basename(filePath)} 没有可翻译文字。`);
    }

    const translatedChunks = [];
    for (const chunk of chunks) {
      translatedChunks.push(await translateChunk({
        chunk,
        provider,
        keys,
        sourceLanguage: request.sourceLanguage,
        targetLanguage: request.targetLanguage,
        tone: request.tone,
        openAIModel: request.openAIModel || "gpt-4o-mini",
        geminiModel: request.geminiModel || "gemini-2.0-flash",
        retryCount: Number(request.retryCount || 1)
      }));
    }

    const outputPath = path.join(outputDir(), `${stripExtension(path.basename(filePath))}.translated.txt`);
    await fs.writeFile(outputPath, translatedChunks.join("\n\n"), "utf8");
    results.push({ inputPath: filePath, outputPath });
  }
  return results;
}

async function translateChunk(options) {
  if (options.provider === "openai") {
    return callOpenAI(options, options.chunk);
  }
  if (options.provider === "gemini") {
    return callGemini(options, options.chunk);
  }
  const draft = await callGemini(options, options.chunk);
  return callOpenAI(options, `请润色以下译文，使其更自然准确：\n\n${draft}`);
}

async function callOpenAI(options, text) {
  return retry(async () => {
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${options.keys.openai}`
      },
      body: JSON.stringify({
        model: options.openAIModel,
        messages: [
          { role: "system", content: translationInstruction(options) },
          { role: "user", content: text }
        ],
        temperature: 0.2
      })
    });
    const body = await response.json();
    if (!response.ok) {
      throw new RetryableHttpError(response.status, body.error?.message || "OpenAI request failed");
    }
    return body.choices?.[0]?.message?.content?.trim() || "";
  }, options.retryCount);
}

async function callGemini(options, text) {
  return retry(async () => {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(options.geminiModel)}:generateContent?key=${encodeURIComponent(options.keys.gemini)}`;
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          { role: "user", parts: [{ text: `${translationInstruction(options)}\n\n${text}` }] }
        ],
        generationConfig: { temperature: 0.2 }
      })
    });
    const body = await response.json();
    if (!response.ok) {
      throw new RetryableHttpError(response.status, body.error?.message || "Gemini request failed");
    }
    return body.candidates?.[0]?.content?.parts?.map((part) => part.text || "").join("").trim() || "";
  }, options.retryCount);
}

function translationInstruction(options) {
  return [
    `把内容从 ${options.sourceLanguage || "自动识别"} 翻译成 ${options.targetLanguage || "中文（简体）"}。`,
    `风格：${options.tone || "自然、准确、适合正式阅读"}。`,
    "只输出译文，不要解释。"
  ].join("\n");
}

async function retry(fn, retryCount) {
  let lastError;
  for (let attempt = 0; attempt <= retryCount; attempt += 1) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      if (!isRetryable(error) || attempt === retryCount) {
        throw error;
      }
      await new Promise((resolve) => setTimeout(resolve, 600 * (attempt + 1)));
    }
  }
  throw lastError;
}

class RetryableHttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function isRetryable(error) {
  if (error instanceof RetryableHttpError) {
    return error.status === 408 || error.status === 429 || error.status >= 500;
  }
  return true;
}

function splitChunks(text, maxCharacters) {
  const trimmed = text.trim();
  if (!trimmed) {
    return [];
  }
  if (trimmed.length <= maxCharacters) {
    return [trimmed];
  }
  const chunks = [];
  let current = "";
  for (const block of trimmed.split(/\n\s*\n/g)) {
    const piece = `${block}\n\n`;
    if (piece.length > maxCharacters) {
      if (current.trim()) {
        chunks.push(current.trim());
        current = "";
      }
      for (let index = 0; index < piece.length; index += maxCharacters) {
        chunks.push(piece.slice(index, index + maxCharacters).trim());
      }
    } else if (current.length + piece.length > maxCharacters) {
      chunks.push(current.trim());
      current = piece;
    } else {
      current += piece;
    }
  }
  if (current.trim()) {
    chunks.push(current.trim());
  }
  return chunks.filter(Boolean);
}

function stripExtension(fileName) {
  return fileName.slice(0, fileName.length - path.extname(fileName).length);
}

function outputDir() {
  return path.join(app.getPath("downloads"), "AutoTranslatorOutput");
}

function keyFilePath() {
  return path.join(app.getPath("userData"), keyFileName);
}

async function loadKeys() {
  try {
    const encrypted = await fs.readFile(keyFilePath());
    const decoded = safeStorage.decryptString(encrypted);
    return JSON.parse(decoded);
  } catch {
    return { openai: "", gemini: "" };
  }
}

async function saveKeys(keys) {
  if (!safeStorage.isEncryptionAvailable()) {
    throw new Error("当前系统不可用 Electron safeStorage，拒绝保存 API Key。");
  }
  const payload = JSON.stringify({
    openai: (keys.openai || "").trim(),
    gemini: (keys.gemini || "").trim()
  });
  const encrypted = safeStorage.encryptString(payload);
  await fs.mkdir(app.getPath("userData"), { recursive: true });
  await fs.writeFile(keyFilePath(), encrypted);
}
