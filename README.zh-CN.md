# Aria 谱匣

本项目直接基于 [hdi200/aria](https://github.com/hdi200/aria) 的完整源码开发，基线为
`9dffd7f3feea6d5af068723d5cfff47e7283a69c`。保留 Aria 的原生触屏界面、编辑流程和
MuseScore 4.7.6 核心，增加只读云端曲库、离线 PDF 识别与 MIDI 转换，并汉化界面。
它是独立的社区版本，与上游作者、MuseScore 官方没有隶属关系。

当前是源码集成阶段，**尚未完成整包构建和实机验收，没有新 APK**。
本轮只面向 Android 手机和平板；不开发、构建或验收 iOS 版本。共享 Swift 源码仍位于上游命名的 MuseReaderiOS 目录。

## 当前功能接入

- 曲库顶部增加“云端曲库”和“PDF 识别”入口，沿用 Aria 的视图组件。
- 云端读取 `guchang233/muse-repo` 的 `catalog.json` 和固定提交的原始文件，不使用 GitHub REST API。
  支持 `mid/`、`mscz/`、`pdf/`，包含子目录、搜索、分类、详情、取消下载、本地缓存与 Git 对象校验。
- 曲谱先保存本地。MSCZ 下载后加入本地乐谱；PDF/MIDI 保存后可进入转换页面。
  云端分类、搜索及滚动锚点由曲库模型保存，关闭再打开不会新建模型。
- PDF 原文件保持完整，可预览原始页面；Android `:omr` 独立进程按页离线识别为 MusicXML，
  再由 Aria 现有核心生成 MSCZ 并加入本地曲库。支持页码范围、进度、取消、多页合并和校对。
  页间乐器/谱表结构无法可靠对应时分别保留，避免错误拼接。
- MIDI 转换保留音符、速度、拍号与乐器信息，进行基本量化、分声部和跨小节延音线处理。
  MIDI 不含完整记谱信息，自动生成的谱面需要校对。复杂重叠节奏分为额外谱表，保留音符。
- 汉化库、编谱、播放、混音、导出、设置、批注、修复及错误提示；乐器和模板名称使用上游中文词库。
  保留文件名、动作 ID、资源路径、音乐格式名称、音名和用户填写的标题。
- Android 应用 ID 为 `app.guchang.aria`，名称“Aria 谱匣”，可以与旧应用共存。
  社区版本不使用上游应用的付费商品和数量限制。

## 目录与数据

本项目位于单独新建的目录。旧 MuseTab 工作区只用于读取迁移参考，没有修改。

| 目录 | 内容 |
| --- | --- |
| `MuseReaderiOS/MuseReaderiOS` | Aria 共享 Swift 界面、曲库和转换会话 |
| `MuseReaderAndroid` | 原生 Android 外壳、推理桥接和后台识别服务 |
| `extensions/omr` | 固定版本的识别源码、模型清单、模型打包与 MIDI 转换 |
| `checks` | 源码检查、汉化字典和功能测试入口 |
| `.local` | 本项目自己的 Python、JVM 验证工具、SDK、模型与构建缓存，忽略提交 |
| `checks/results` | 私有测试输入、识别结果与报告，忽略提交 |

在设备上，下载文件存于应用私有 `CloudScores`，原 PDF 导入副本在 `PDFSources`，
识别任务在 `conversion-jobs`；转换结果加入 Aria 的 `Scores`。本地编辑不上传云端。

## 构建与验证

完整 Android 构建仍沿用[上游流程](MuseReaderAndroid/README.md)，要求相匹配的
Swift 6.4.1 / Android SDK、Skip、JDK 21、NDK r27c、Qt 6.11.1 及其 macOS host 工具。
上游验证的主机是 macOS；当前 Windows 环境尚未完成该整包工具链。

本版本另需 Python 3.10 用于 Chaquopy 构建：

```sh
export ARIA_BUILD_PYTHON=/absolute/path/to/python3.10
python3 extensions/omr/prepare_models.py .local/staged-assets
```

Gradle 会调用同一脚本校验、缓存并打包离线模型。模型在构建时下载，安装后识别无需联网。
Swift-only 修改不要重复构建未更改的 MuseScore 核心。Qt、音色库、模型与许可证必须一起打包。

```powershell
.local/venv/Scripts/python.exe -m pytest extensions/omr/tests -q -o cache_dir=.local/pytest-cache
.local/venv/Scripts/python.exe checks/localization.py
```

Swift 云端协议检查需要 Swift 编译器：

```sh
swiftc MuseReaderiOS/MuseReaderiOS/Services/CloudScoreLibrary.swift checks/CloudScoreChecks.swift -o .local/cloud-check
.local/cloud-check
```

详细的已验证项目、待验收项目和限制见 [迁移记录](docs/MUSETAB-MIGRATION.md)。
没有本地 Mac 时，可在新仓库中手动运行 Aria MuseTab Android (manual) 工作流。
工作流仅构建 Android 调试 APK 并输出 artifact，不自动发布、不需要签名密码；目前尚未执行验证。

## 来源和许可

保留上游许可证、版权及通知。新增识别模块基于 Andromr/homr，源码固定版本、许可证和模型
校验清单见 [extensions/omr](extensions/omr/README.md)。原始法律文本保留原文，不以中文解释替代。
本地模型、用户乐谱及测试输出不作为源码发布内容。
