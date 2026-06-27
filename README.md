# Auto Translator Native

一个 macOS 原生桌面自动翻译工具，使用 SwiftUI 构建。它支持拖拽文件、选择 OpenAI / GPT、Gemini 或双引擎翻译，并把译文保存到本机 Downloads 输出目录。

## 当前定位

- 本地正式源码 repo：`/Users/laura/Downloads/AutoTranslatorDeliverables/SourceRepo`
- GitHub repo：`https://github.com/ggglitter/auto-translator-native`
- 源码入口：`Sources/main.swift`
- 打包资源：`Resources/Info.plist`
- 本地构建产物：`Auto Translator Native.app`
- 跨平台发布轨道：`desktop/electron/`
- 默认输出目录：`/Users/laura/Downloads/AutoTranslatorOutput`

## 功能

- SwiftUI 原生窗口，不依赖 Electron 或本地网页服务
- 支持拖拽文件和文件选择器
- 支持 OpenAI / GPT、Gemini、Gemini 初译 + OpenAI 润色的双引擎模式
- API Key 通过 macOS 钥匙串保存，不写入仓库
- 支持 `txt`、`md`、`csv`、`json`、`html`、`srt`、`pdf`、`docx` 等文件的文本抽取和翻译

## 使用

运行本地构建产物：

```zsh
open "Auto Translator Native.app"
```

第一次使用时，在右侧填入 OpenAI / GPT API Key 和 Gemini API Key，然后点击“保存 Key 到钥匙串”。不要把真实 API Key 写入仓库文件、文档、提交信息或聊天记录。

## 重新编译

修改源码后运行：

```zsh
./build.sh
```

脚本会在临时目录重新生成并验证 `Auto Translator Native.app`，再复制到 repo 根目录，复制 `Resources/Info.plist`，并做本地 ad-hoc 签名验证。

当前 repo 位于 macOS Documents 路径时，系统可能给最终 `.app` 自动添加或重新添加 file-provider 扩展属性；这会让事后的 `codesign --verify --deep --strict` 报资源属性残留。脚本在 `/tmp` 中的干净 bundle 上完成签名验证，再复制回本地开发目录。

## 本地打包

生成本地 zip 包和校验文件：

```zsh
./scripts/package_local_app.sh
```

产物会写到 `/tmp/autotranslator-packages-*`，不会上传或发布。

## 本地安全检查

提交前可先运行：

```zsh
./scripts/check_repo_safety.sh
```

它会确认 Git 远端为空或只指向 `ggglitter/auto-translator-native`，本地构建产物仍被忽略，并扫描真实密钥样式的字符串。

## Windows / macOS 发布轨道

跨平台版本位于：

```zsh
desktop/electron
```

该轨道使用 Electron、`electron-builder` 和 `electron-updater`。GitHub Actions 会在 Windows 和 macOS runner 上构建安装包，并通过 GitHub Release 元数据提供 OTA 更新。

发布产物下载后可离线验收：

```zsh
./scripts/check_release_artifacts.sh /path/to/release-artifacts
```

签名/公证计划见 `docs/SIGNING_NOTARIZATION_PLAN.md`。HTTPS push、域名和独立 HTTPS OTA host 放在最后处理。

## 仓库约束

- 当前目标已授权 GitHub 发布、push、Windows/macOS 构建和 OTA。
- 首个本地提交记录见 `docs/FIRST_COMMIT_PLAN.md`。
- 后续 push、release、域名和 HTTPS OTA host 需要按当前发布 gate 单独执行。
- 不保存真实 API Key。
- `Auto Translator Native.app/` 和 `work/` 是本地构建产物，不作为源码纳入版本控制。
