# 离线 PDF 识别

Android 的独立 `:omr` 进程使用 PdfRenderer 按页渲染，再通过 Chaquopy 调用 Andromr/homr。
分割与编码使用 LiteRT，解码使用 ONNX Runtime；原始 PDF 不修改、不上传。
MusicXML 识别结果交给 Aria 原有核心，保存为真正的 MSCZ 后加入本地曲库。

上游 Andromr 固定为 `d8005852211026c5a67f6fededb6d4cede6680d5`，源文件在
`python/homr/`，许可证在 `ANDROMR-LICENSE.txt`。移植去除了 Kivy 全局状态依赖，
改用 `aria_omr_runtime`，Java 桥接由 PyJNIus 改为 Chaquopy，推理类包名为 `aria.skip.omr`。
模型版本和下载地址记录在 `models.json`。三个模型 SHA-256 在识别前校验。

模型放在项目内 `.local/omr-models/`，构建时作为离线资源打包。
不要使用用户上传的 PDF 作为公开测试样本。识别不保证完全正确，转换后必须提供校对入口。
结构一致的多页结果会合并；无法确认乐器/谱表对应时分别保存页面结果并提示。
