import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const requiredFiles = [
  "package.json",
  "src/main.js",
  "src/preload.js",
  "src/renderer/index.html",
  "src/renderer/styles.css",
  "src/renderer/app.js"
];

for (const relativePath of requiredFiles) {
  const filePath = path.join(root, relativePath);
  if (!fs.existsSync(filePath)) {
    throw new Error(`Missing required Electron file: ${relativePath}`);
  }
}

const pkg = JSON.parse(fs.readFileSync(path.join(root, "package.json"), "utf8"));
const build = pkg.build || {};
const publish = build.publish?.[0] || {};
const scripts = pkg.scripts || {};

if (build.appId !== "com.codex.autotranslator.native") {
  throw new Error("Unexpected Electron appId.");
}
if (publish.provider !== "github") {
  throw new Error("Electron updater publish provider must be github.");
}
if (publish.owner !== "ggglitter" || publish.repo !== "auto-translator-native") {
  throw new Error("Electron updater GitHub owner/repo mismatch.");
}
for (const dependency of ["electron-updater", "mammoth", "pdf-parse"]) {
  if (!pkg.dependencies?.[dependency]) {
    throw new Error(`Missing runtime dependency: ${dependency}`);
  }
}
for (const scriptName of ["check", "dist", "dist:mac", "dist:mac:universal", "dist:mac:arm64", "dist:mac:x64", "dist:win"]) {
  if (!scripts[scriptName]) {
    throw new Error(`Missing package script: ${scriptName}`);
  }
}
if (!scripts["dist:mac"].includes("dist:mac:universal")) {
  throw new Error("Default mac release script must build the universal mac package.");
}
if (!scripts["dist:mac:universal"].includes("--universal")) {
  throw new Error("Universal mac release script must pass --universal to electron-builder.");
}
if (!scripts["dist:mac:arm64"].includes("--arm64")) {
  throw new Error("arm64 mac release script must pass --arm64 to electron-builder.");
}
if (!scripts["dist:mac:x64"].includes("--x64")) {
  throw new Error("x64 mac release script must pass --x64 to electron-builder.");
}

const rendererHtml = fs.readFileSync(path.join(root, "src/renderer/index.html"), "utf8");
for (const id of ["checkUpdatesBtn", "downloadUpdateBtn", "installUpdateBtn"]) {
  if (!rendererHtml.includes(`id="${id}"`)) {
    throw new Error(`Missing OTA control in renderer HTML: ${id}`);
  }
}

const rendererJs = fs.readFileSync(path.join(root, "src/renderer/app.js"), "utf8");
for (const functionName of ["checkUpdates", "downloadUpdate", "installUpdate", "applyUpdateState"]) {
  if (!rendererJs.includes(`function ${functionName}`)) {
    throw new Error(`Missing OTA renderer function: ${functionName}`);
  }
}

console.log("electron_config_ok");
