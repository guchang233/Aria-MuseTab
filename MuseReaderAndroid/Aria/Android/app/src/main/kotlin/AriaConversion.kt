// SPDX-License-Identifier: GPL-3.0-or-later
package aria.skip

import android.app.*
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import org.json.JSONArray
import org.json.JSONObject
import skip.ui.UIApplication
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** JNI facade. Only paths and small JSON status cross the Swift boundary. */
class AriaConversion {
    fun pdfPageCount(source: String): Int = ParcelFileDescriptor.open(File(source), ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
        PdfRenderer(descriptor).use { it.pageCount }
    }
    fun pdfPreview(source: String, index: Int): String {
        val context = UIApplication.shared.androidActivity?.applicationContext ?: error("应用未就绪")
        val sourceFile = File(source)
        val target = File(context.cacheDir, "pdf-previews/${sourceFile.path.hashCode()}-${sourceFile.lastModified()}-$index.png")
        if (target.exists()) return target.path
        target.parentFile?.mkdirs()
        ParcelFileDescriptor.open(sourceFile, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
            PdfRenderer(descriptor).use { renderer ->
                renderer.openPage(index).use { page ->
                    val scale = minOf(2.0, 2000.0 / maxOf(page.width, page.height))
                    val bitmap = Bitmap.createBitmap(maxOf(1, (page.width * scale).toInt()), maxOf(1, (page.height * scale).toInt()), Bitmap.Config.ARGB_8888)
                    try {
                        Canvas(bitmap).drawColor(Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        target.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
                    } finally { bitmap.recycle() }
                }
            }
        }
        return target.path
    }
    fun start(source: String, pages: String): String {
        val context = UIApplication.shared.androidActivity?.applicationContext
            ?: error("应用尚未就绪，请返回曲库后重试")
        val job = File(context.filesDir, "conversion-jobs/${UUID.randomUUID()}").apply { mkdirs() }
        File(job, "status.json").writeText(JSONObject().put("state", "running")
            .put("message", "正在准备离线转换").put("progress", 0).toString())
        File(job, "heartbeat").writeText("")
        val intent = Intent(context, AriaConversionService::class.java)
            .putExtra("source", source).putExtra("pages", pages).putExtra("job", job.path)
        context.startForegroundService(intent)
        return job.path
    }
    fun cancel(job: String) {
        val context = UIApplication.shared.androidActivity?.applicationContext ?: return
        val root = File(context.filesDir, "conversion-jobs").canonicalFile
        val folder = File(job).canonicalFile
        require(folder.parentFile == root) { "无效的识别任务" }
        File(folder, "cancel").writeText("")
    }
}

/** Separate process: recognition cannot block Aria's render/audio threads or retain its heap. */
class AriaConversionService : Service() {
    private val executor = Executors.newSingleThreadExecutor()
    private val heartbeat = Executors.newSingleThreadScheduledExecutor()
    @Volatile private var activeJob: File? = null
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onCreate() {
        super.onCreate()
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel("offline-omr", "离线曲谱识别", NotificationManager.IMPORTANCE_LOW))
        heartbeat.scheduleAtFixedRate({
            activeJob?.let { job -> runCatching { File(job, "heartbeat").writeText("") } }
        }, 0, 5, TimeUnit.SECONDS)
    }
    override fun onDestroy() {
        heartbeat.shutdownNow()
        executor.shutdownNow()
        super.onDestroy()
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val jobPath = intent?.getStringExtra("job") ?: run { stopSelf(startId); return START_NOT_STICKY }
        val job = File(jobPath).canonicalFile
        require(job.parentFile == File(filesDir, "conversion-jobs").canonicalFile)
        if (intent.action == "cancel") { File(job, "cancel").writeText(""); return START_NOT_STICKY }
        if (activeJob != null) {
            status(job, "error", "已有识别任务正在运行，请稍后重试")
            return START_NOT_STICKY
        }
        activeJob = job
        val cancel = PendingIntent.getService(this, 0, Intent(this, javaClass).setAction("cancel")
            .putExtra("job", job.path), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = Notification.Builder(this, "offline-omr").setSmallIcon(android.R.drawable.ic_menu_edit)
            .setContentTitle("正在离线转换曲谱").setContentText("原文件保留在本地，识别后请校对结果")
            .setOngoing(true).addAction(Notification.Action.Builder(null, "取消", cancel).build()).build()
        startForeground(7701, notification)
        val source = intent.getStringExtra("source") ?: ""
        val pages = intent.getStringExtra("pages") ?: "1"
        executor.execute {
            try { convert(File(source), pages, job) }
            catch (error: Throwable) {
                android.util.Log.e("AriaOMR", "Offline conversion failed", error)
                status(job, if (File(job, "cancel").exists()) "cancelled" else "error",
                    if (File(job, "cancel").exists()) "识别已取消" else "转换失败：${error.message ?: "内存不足或识别核心异常"}")
            } finally {
                activeJob = null
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }
    private fun status(job: File, state: String, message: String, outputs: List<String> = emptyList()) {
        val temporary = File(job, "status.kotlin.tmp")
        temporary.writeText(JSONObject().put("state", state).put("message", message)
            .put("progress", if (state == "done") 1 else 0).put("outputs", JSONArray(outputs)).toString())
        check(temporary.renameTo(File(job, "status.json")))
    }
    private fun convert(source: File, pageRange: String, job: File) {
        require(source.isFile && source.length() <= 128L * 1024 * 1024) { "文件不存在或超过 128 MB" }
        if (!Python.isStarted()) Python.start(AndroidPlatform(this))
        val module = Python.getInstance().getModule("aria_conversion")
        if (source.extension.lowercase() in listOf("mid", "midi")) {
            val output = File(job, "midi.musicxml")
            Python.getInstance().getModule("aria_midi").callAttr("convert", source.path, output.path)
            status(job, "done", "MIDI 已转换，请校对量化与分声部结果", listOf(output.path))
            return
        }
        require(source.extension.lowercase() == "pdf") { "请选择 PDF 或 MIDI 文件" }
        val models = File(filesDir, "omr-models").apply { mkdirs() }
        for (name in assets.list("omr-models") ?: emptyArray()) {
            val target = File(models, name)
            if (!target.exists()) {
                val temporary = File(models, "$name.partial")
                assets.open("omr-models/$name").use { input -> temporary.outputStream().use { input.copyTo(it) } }
                check(temporary.renameTo(target))
            }
        }
        module.callAttr("validate_models", models.path)
        val outputs = mutableListOf<String>()
        ParcelFileDescriptor.open(source, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
            PdfRenderer(descriptor).use { pdf ->
                val indices = parsePages(pageRange, pdf.pageCount)
                for ((index, pageIndex) in indices.withIndex()) {
                    if (File(job, "cancel").exists()) error("识别已取消")
                    val image = File(job, "page-${pageIndex + 1}.png")
                    pdf.openPage(pageIndex).use { page ->
                        val scale = minOf(300.0 / 72, 2400.0 / maxOf(page.width, page.height))
                        val bitmap = Bitmap.createBitmap(maxOf(1, (page.width * scale).toInt()),
                            maxOf(1, (page.height * scale).toInt()), Bitmap.Config.ARGB_8888)
                        try {
                            Canvas(bitmap).drawColor(Color.WHITE)
                            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                            image.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
                        } finally { bitmap.recycle() }
                    }
                    val xml = File(job, "page-${pageIndex + 1}.musicxml")
                    module.callAttr("recognize_page", image.path, xml.path, models.path,
                        File(job, "status.json").path, File(job, "cancel").path, index + 1, indices.size)
                    outputs.add(xml.path)
                }
            }
        }
        if (File(job, "cancel").exists()) error("识别已取消")
        val merged = JSONObject(module.callAttr("finish", JSONArray(outputs).toString(), File(job, "recognized.musicxml").path).toString())
        val finalOutputs = merged.getJSONArray("outputs")
        status(job, "done", merged.getString("warning"), (0 until finalOutputs.length()).map { finalOutputs.getString(it) })
    }
    companion object {
        fun parsePages(text: String, total: Int): List<Int> {
            if (text.trim() in listOf("", "all", "全部")) return (0 until total).toList()
            val pages = sortedSetOf<Int>()
            for (piece in text.replace('，', ',').split(',')) {
                val span = piece.trim().split('-')
                require(span.size in 1..2) { "页码格式应为 1、1-3 或 1,3,5" }
                val first = span[0].trim().toInt()
                val last = span.last().trim().toInt()
                require(first in 1..total && last in first..total) { "页码超出 PDF 范围" }
                pages.addAll((first..last).map { it - 1 })
            }
            require(pages.isNotEmpty())
            return pages.toList()
        }
    }
}
