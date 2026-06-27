const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("autoTranslator", {
  getState: () => ipcRenderer.invoke("app:get-state"),
  pickFiles: () => ipcRenderer.invoke("files:pick"),
  describeFiles: (paths) => ipcRenderer.invoke("files:describe", paths),
  previewFile: (path) => ipcRenderer.invoke("files:preview", path),
  loadKeys: () => ipcRenderer.invoke("keys:load"),
  saveKeys: (keys) => ipcRenderer.invoke("keys:save", keys),
  translate: (request) => ipcRenderer.invoke("translate:start", request),
  openPath: (path) => ipcRenderer.invoke("shell:open-path", path),
  checkUpdates: () => ipcRenderer.invoke("updates:check"),
  downloadUpdate: () => ipcRenderer.invoke("updates:download"),
  installUpdate: () => ipcRenderer.invoke("updates:install"),
  onUpdateState: (callback) => {
    ipcRenderer.on("updates:state", (_event, state) => callback(state));
  }
});
