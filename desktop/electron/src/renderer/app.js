const state = {
  files: [],
  selectedPath: "",
  outputDir: ""
};

const $ = (id) => document.getElementById(id);

const elements = {
  addFilesBtn: $("addFilesBtn"),
  clearFilesBtn: $("clearFilesBtn"),
  translateBtn: $("translateBtn"),
  previewBtn: $("previewBtn"),
  openOutputBtn: $("openOutputBtn"),
  saveKeysBtn: $("saveKeysBtn"),
  checkUpdatesBtn: $("checkUpdatesBtn"),
  downloadUpdateBtn: $("downloadUpdateBtn"),
  installUpdateBtn: $("installUpdateBtn"),
  closePreviewBtn: $("closePreviewBtn"),
  dropZone: $("dropZone"),
  fileList: $("fileList"),
  fileCount: $("fileCount"),
  statusText: $("statusText"),
  previewPanel: $("previewPanel"),
  previewTitle: $("previewTitle"),
  previewText: $("previewText")
};

window.addEventListener("DOMContentLoaded", async () => {
  const appState = await window.autoTranslator.getState();
  state.outputDir = appState.outputDir;
  setStatus(`准备好了。当前版本 ${appState.version}。`);

  const keys = await window.autoTranslator.loadKeys();
  $("openaiKey").value = keys.openai || "";
  $("geminiKey").value = keys.gemini || "";

  window.autoTranslator.onUpdateState(applyUpdateState);
  applyUpdateState(appState.updates);

  elements.addFilesBtn.addEventListener("click", addFiles);
  elements.clearFilesBtn.addEventListener("click", clearFiles);
  elements.translateBtn.addEventListener("click", translateFiles);
  elements.previewBtn.addEventListener("click", previewSelected);
  elements.openOutputBtn.addEventListener("click", () => window.autoTranslator.openPath(state.outputDir));
  elements.saveKeysBtn.addEventListener("click", saveKeys);
  elements.checkUpdatesBtn.addEventListener("click", checkUpdates);
  elements.downloadUpdateBtn.addEventListener("click", downloadUpdate);
  elements.installUpdateBtn.addEventListener("click", installUpdate);
  elements.closePreviewBtn.addEventListener("click", () => {
    elements.previewPanel.hidden = true;
  });

  elements.dropZone.addEventListener("dragover", (event) => {
    event.preventDefault();
    elements.dropZone.classList.add("dragging");
  });
  elements.dropZone.addEventListener("dragleave", () => {
    elements.dropZone.classList.remove("dragging");
  });
  elements.dropZone.addEventListener("drop", async (event) => {
    event.preventDefault();
    elements.dropZone.classList.remove("dragging");
    const paths = [...event.dataTransfer.files].map((file) => file.path).filter(Boolean);
    const described = await window.autoTranslator.describeFiles(paths);
    appendFiles(described);
  });

  renderFiles();
});

async function addFiles() {
  const files = await window.autoTranslator.pickFiles();
  appendFiles(files);
}

function appendFiles(files) {
  let added = 0;
  for (const file of files) {
    if (state.files.some((item) => item.path === file.path)) {
      continue;
    }
    state.files.push(file);
    if (!state.selectedPath) {
      state.selectedPath = file.path;
    }
    added += 1;
  }
  setStatus(added ? `已添加 ${state.files.length} 个文件。` : "文件已在列表中。");
  renderFiles();
}

function clearFiles() {
  state.files = [];
  state.selectedPath = "";
  renderFiles();
  setStatus("已清空文件列表。");
}

function renderFiles() {
  elements.fileCount.textContent = `${state.files.length} 个文件`;
  elements.fileList.innerHTML = "";
  elements.fileList.classList.toggle("empty", state.files.length === 0);

  if (state.files.length === 0) {
    elements.fileList.textContent = "还没有文件";
    return;
  }

  for (const file of state.files) {
    const row = document.createElement("button");
    row.type = "button";
    row.className = `file-row ${state.selectedPath === file.path ? "selected" : ""}`;
    row.innerHTML = `
      <div>
        <strong>${escapeHtml(file.name)}</strong>
        <span>${escapeHtml(file.path)}</span>
      </div>
      <span>${formatBytes(file.size)}</span>
    `;
    row.addEventListener("click", () => {
      state.selectedPath = file.path;
      renderFiles();
      setStatus(`已选择 ${file.name}。`);
    });
    elements.fileList.appendChild(row);
  }
}

async function previewSelected() {
  if (!state.selectedPath) {
    setStatus("先添加并选择要预览的文件。", true);
    return;
  }
  try {
    const preview = await window.autoTranslator.previewFile(state.selectedPath);
    elements.previewTitle.textContent = preview.title;
    elements.previewText.textContent = preview.text;
    elements.previewPanel.hidden = false;
    setStatus("抽取预览已生成。");
  } catch (error) {
    setStatus(`预览失败：${error.message}`, true);
  }
}

async function saveKeys() {
  try {
    await window.autoTranslator.saveKeys({
      openai: $("openaiKey").value,
      gemini: $("geminiKey").value
    });
    setStatus("API Key 已保存到本机加密存储。");
  } catch (error) {
    setStatus(`保存失败：${error.message}`, true);
  }
}

async function translateFiles() {
  if (state.files.length === 0) {
    setStatus("先添加要翻译的文件。", true);
    return;
  }

  elements.translateBtn.disabled = true;
  setStatus("正在翻译...");
  try {
    const results = await window.autoTranslator.translate({
      files: state.files.map((file) => file.path),
      provider: $("provider").value,
      sourceLanguage: $("sourceLanguage").value,
      targetLanguage: $("targetLanguage").value,
      tone: $("tone").value,
      openAIModel: $("openaiModel").value,
      geminiModel: $("geminiModel").value,
      maxChunkCharacters: Number($("maxChunkCharacters").value),
      retryCount: Number($("retryCount").value)
    });
    setStatus(`翻译完成，已保存 ${results.length} 个文件到 Downloads。`);
  } catch (error) {
    setStatus(`翻译失败：${error.message}`, true);
  } finally {
    elements.translateBtn.disabled = false;
  }
}

async function checkUpdates() {
  try {
    const result = await window.autoTranslator.checkUpdates();
    applyUpdateState(result);
  } catch (error) {
    setStatus(`更新检查失败：${error.message}`, true);
  }
}

async function downloadUpdate() {
  try {
    elements.downloadUpdateBtn.disabled = true;
    const result = await window.autoTranslator.downloadUpdate();
    applyUpdateState(result);
  } catch (error) {
    setStatus(`更新下载失败：${error.message}`, true);
    elements.downloadUpdateBtn.disabled = false;
  }
}

async function installUpdate() {
  try {
    await window.autoTranslator.installUpdate();
  } catch (error) {
    setStatus(`更新安装失败：${error.message}`, true);
  }
}

function applyUpdateState(updateState = {}) {
  const status = updateState.status || "idle";
  const message = updateState.message || "未检查更新。";
  elements.downloadUpdateBtn.disabled = status !== "available";
  elements.installUpdateBtn.disabled = status !== "downloaded";
  setStatus(message, status === "error");
}

function setStatus(message, isError = false) {
  elements.statusText.textContent = message;
  elements.statusText.classList.toggle("error", isError);
}

function formatBytes(bytes) {
  return new Intl.NumberFormat("zh-CN", {
    style: "unit",
    unit: "byte",
    unitDisplay: "narrow"
  }).format(bytes);
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
