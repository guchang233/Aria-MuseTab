# MuseTab → Aria 迁移记录

日期：2026-11-15。直接使用 Aria 源码，不再继续原 MuseTab 的界面与 WASM 编谱工作台。
当前只考虑 Android 手机和平板。共享 Swift 文件所在目录的上游名称保留，不代表维护 iOS 产品。
基线提交：`9dffd7f3feea6d5af068723d5cfff47e7283a69c`。
原工作区未改动；所有新代码、依赖和结果位于新建的根目录文件夹。

## 已进行的检查

- 真实云端静态清单：573 个文件。分别抽取 MID、MSCZ、PDF，大小与 Git blob SHA-1 全部匹配。
  Swift 云端协议和 Git blob SHA-1 检查已在 macOS runner 编译运行通过；Swift UI 和 URLSession 调用尚未在 App 内验证。
- 离线 PDF → MusicXML：本项目内的 Python、模型与适配源码完成一页识别；与参考谱比较，
  32 个音符的音高、时值、谱表及小节位置全部一致。不能据此推断复杂乐谱的识别准确率。
- MIDI：云端 MIDI 及用户此前提供的 Animenz MIDI 均完成 MusicXML 转换。
  已用额外谱表处理超过四个重叠声部的情况，没有通过截断音符来适应声部数量。
- Python 测试验证 MIDI 的速度/拍号/重叠/跨小节延音、截断输入、多页拼接和结构不一致时保留页面结果。
- Java 推理类已使用实际 LiteRT 2.1.6、ONNX Runtime 1.27.0 与 Android 36 API 编译。
- Kotlin 识别服务已使用实际 Android 36、Chaquopy 17.2 API 编译；仅 Aria 的 `UIApplication` 访问器使用编译桩。
- 独立 Android library 检查已完成真实 Gradle/AGP/Chaquopy 编译与资源打包，生成约 93 MB AAR；
  包含 Python 3.10、OpenCV、NumPy、Java/Kotlin 推理类和三个离线模型。
  这项检查不包含 Swift/Skip 主界面，AAR 也不是可安装的 APK。
- Swift 源码语法树与上游基线比较，没有新增解析错误。这不等同于 Swift 类型检查或整包编译。
- MuseScore 原生核心与 Android 引擎已在 macOS runner 完成编译并缓存；整包构建还需验证 Skip 的 Swift 工具链选择及共享界面。

## 尚未完成的验收

1. 用完整 Swift/Skip 工具链进行共享界面类型检查及 Android APK 构建。
2. 在目标平板打开云端 → 下载 → 本地曲库 → 看谱/编辑/播放，验证导航和滚动位置恢复。
3. 在目标平板执行 PDF → 独立进程识别 → MusicXML → Aria 核心 → MSCZ → 播放的完整链路。
4. 验证横竖屏、手机/平板、深色模式、批注、声音设置、识别取消及系统后台行为。
5. 用复杂钢琴谱校对识别质量、MIDI 量化、内存峰值和转换耗时。

## 平台与依赖说明

- PDF 推理当前接入 Android；iOS 共用云端、汉化和转换界面，但没有内置相同的 Python 推理运行时，
  会明确提示平台限制，不模拟成功。
- 当前 Android OpenCV 可用二进制组合为 Python 3.10 / NumPy 1.26.2 / OpenCV headless 4.5.1.48。
  这与桌面验证的 Python 3.11 / OpenCV 4.7 不同，必须实机验证；16 KB 页面设备兼容性也尚未验证。
- 识别模型约 75 MB，加上 Python/OpenCV 及音色库会增加安装包大小。当前全部离线打包，不运行公共识别服务器。
- 识别结果不是原 PDF 上的精确音符定位。播放与编辑发生在生成的 MSCZ 中，原 PDF 用于对照。
- 用户授权的公开 fork 为 `guchang233/Aria-MuseTab`；源码已提交并推送，Android 工作流正在验证。尚未发布应用，也没有替换已安装的 MuseTab。
