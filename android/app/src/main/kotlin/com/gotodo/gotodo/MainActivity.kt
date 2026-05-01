package com.gotodo.gotodo

import android.Manifest
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private var eventSink: EventChannel.EventSink? = null
    private var timerReceiver: BroadcastReceiver? = null
    private var pendingBackupResult: MethodChannel.Result? = null
    private var pendingBackupSourcePath: String? = null
    private var pendingRestoreResult: MethodChannel.Result? = null
    private var pendingRestoreTargetPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "gotodo/timer"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    requestNotificationPermissionIfNeeded()
                    startTimerService(call)
                    result.success(null)
                }
                "pause" -> {
                    sendTimerAction(FocusTimerService.ACTION_PAUSE)
                    result.success(null)
                }
                "resume" -> {
                    sendTimerAction(FocusTimerService.ACTION_RESUME)
                    result.success(null)
                }
                "stop" -> {
                    sendTimerAction(FocusTimerService.ACTION_STOP)
                    result.success(null)
                }
                "complete" -> {
                    sendTimerAction(FocusTimerService.ACTION_COMPLETE)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "gotodo/storage"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "backupDatabaseToDownloads" -> handleBackupToDownloads(call, result)
                "backupDatabaseWithPicker" -> handleBackupWithPicker(call, result)
                "restoreDatabaseWithPicker" -> handleRestoreWithPicker(call, result)
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "gotodo/timer_events"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                registerTimerReceiver()
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                unregisterTimerReceiver()
            }
        })
    }

    override fun onDestroy() {
        unregisterTimerReceiver()
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            BACKUP_CREATE_DOCUMENT_REQUEST -> finishBackupWithPicker(resultCode, data)
            RESTORE_OPEN_DOCUMENT_REQUEST -> finishRestoreWithPicker(resultCode, data)
        }
    }

    private fun startTimerService(call: MethodCall) {
        val projectName = call.argument<String>("projectName") ?: "专注中"
        val mode = call.argument<String>("mode") ?: "count_up"
        val startAtMillis = (call.argument<Number>("startAtMillis")
            ?: System.currentTimeMillis()).toLong()
        val plannedSeconds = (call.argument<Number>("plannedSeconds") ?: 0).toInt()
        val soundEnabled = call.argument<Boolean>("soundEnabled") ?: true
        val vibrationEnabled = call.argument<Boolean>("vibrationEnabled") ?: true

        val intent = Intent(this, FocusTimerService::class.java).apply {
            action = FocusTimerService.ACTION_START
            putExtra(FocusTimerService.EXTRA_PROJECT_NAME, projectName)
            putExtra(FocusTimerService.EXTRA_MODE, mode)
            putExtra(FocusTimerService.EXTRA_START_AT_MILLIS, startAtMillis)
            putExtra(FocusTimerService.EXTRA_PLANNED_SECONDS, plannedSeconds)
            putExtra(FocusTimerService.EXTRA_SOUND_ENABLED, soundEnabled)
            putExtra(FocusTimerService.EXTRA_VIBRATION_ENABLED, vibrationEnabled)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun sendTimerAction(action: String) {
        startService(Intent(this, FocusTimerService::class.java).apply {
            this.action = action
        })
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST
            )
        }
    }

    private fun registerTimerReceiver() {
        if (timerReceiver != null) return
        timerReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                eventSink?.success(
                    mapOf(
                        "status" to intent?.getStringExtra("status"),
                        "elapsedSeconds" to intent?.getIntExtra("elapsedSeconds", 0),
                        "remainingSeconds" to intent?.getIntExtra("remainingSeconds", 0)
                    )
                )
            }
        }
        val filter = IntentFilter(FocusTimerService.ACTION_TIMER_EVENT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(timerReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(timerReceiver, filter)
        }
    }

    private fun handleBackupToDownloads(call: MethodCall, result: MethodChannel.Result) {
        val sourcePath = call.argument<String>("sourcePath")
        val fileName = call.argument<String>("fileName")
        if (sourcePath.isNullOrBlank() || fileName.isNullOrBlank()) {
            result.error("invalid_args", "备份参数不完整", null)
            return
        }
        try {
            result.success(backupToDownloads(sourcePath, fileName))
        } catch (error: Exception) {
            result.error("backup_failed", error.message ?: "备份失败", null)
        }
    }

    private fun handleBackupWithPicker(call: MethodCall, result: MethodChannel.Result) {
        val sourcePath = call.argument<String>("sourcePath")
        val fileName = call.argument<String>("fileName")
        if (sourcePath.isNullOrBlank() || fileName.isNullOrBlank()) {
            result.error("invalid_args", "备份参数不完整", null)
            return
        }
        if (pendingBackupResult != null || pendingRestoreResult != null) {
            result.error("storage_busy", "已有数据操作正在进行", null)
            return
        }
        pendingBackupResult = result
        pendingBackupSourcePath = sourcePath
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            type = "application/vnd.sqlite3"
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
        try {
            startActivityForResult(intent, BACKUP_CREATE_DOCUMENT_REQUEST)
        } catch (error: Exception) {
            pendingBackupResult = null
            pendingBackupSourcePath = null
            result.error("backup_failed", error.message ?: "无法打开保存位置选择器", null)
        }
    }

    private fun handleRestoreWithPicker(call: MethodCall, result: MethodChannel.Result) {
        val targetPath = call.argument<String>("targetPath")
        if (targetPath.isNullOrBlank()) {
            result.error("invalid_args", "恢复参数不完整", null)
            return
        }
        if (pendingBackupResult != null || pendingRestoreResult != null) {
            result.error("storage_busy", "已有数据操作正在进行", null)
            return
        }
        pendingRestoreResult = result
        pendingRestoreTargetPath = targetPath
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            type = "*/*"
        }
        try {
            startActivityForResult(intent, RESTORE_OPEN_DOCUMENT_REQUEST)
        } catch (error: Exception) {
            pendingRestoreResult = null
            pendingRestoreTargetPath = null
            result.error("restore_failed", error.message ?: "无法打开文件选择器", null)
        }
    }

    private fun finishBackupWithPicker(resultCode: Int, data: Intent?) {
        val callback = pendingBackupResult ?: return
        val sourcePath = pendingBackupSourcePath
        pendingBackupResult = null
        pendingBackupSourcePath = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            callback.success(null)
            return
        }
        if (sourcePath.isNullOrBlank()) {
            callback.error("backup_failed", "备份源文件不存在", null)
            return
        }
        try {
            copyFileToUri(File(sourcePath), data.data!!)
            callback.success(data.data.toString())
        } catch (error: Exception) {
            callback.error("backup_failed", error.message ?: "备份失败", null)
        }
    }

    private fun finishRestoreWithPicker(resultCode: Int, data: Intent?) {
        val callback = pendingRestoreResult ?: return
        val targetPath = pendingRestoreTargetPath
        pendingRestoreResult = null
        pendingRestoreTargetPath = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            callback.success(false)
            return
        }
        if (targetPath.isNullOrBlank()) {
            callback.error("restore_failed", "恢复目标文件不存在", null)
            return
        }
        try {
            restoreDatabaseFromUri(data.data!!, File(targetPath))
            callback.success(true)
        } catch (error: Exception) {
            callback.error("restore_failed", error.message ?: "恢复失败", null)
        }
    }

    private fun backupToDownloads(sourcePath: String, fileName: String): String {
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) throw IllegalStateException("数据库文件不存在")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/vnd.sqlite3")
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    "${Environment.DIRECTORY_DOWNLOADS}/GoToDoBak"
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("无法创建备份文件")
            try {
                copyFileToUri(sourceFile, uri)
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
            } catch (error: Exception) {
                contentResolver.delete(uri, null, null)
                throw error
            }
            return "${Environment.DIRECTORY_DOWNLOADS}/GoToDoBak/$fileName"
        }

        @Suppress("DEPRECATION")
        val backupDir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "GoToDoBak"
        )
        if (!backupDir.exists() && !backupDir.mkdirs()) {
            throw IllegalStateException("无法创建备份目录")
        }
        val target = File(backupDir, fileName)
        sourceFile.inputStream().use { input ->
            target.outputStream().use { output -> input.copyTo(output) }
        }
        return target.absolutePath
    }

    private fun copyFileToUri(sourceFile: File, uri: Uri) {
        if (!sourceFile.exists()) throw IllegalStateException("数据库文件不存在")
        val output = contentResolver.openOutputStream(uri, "w")
            ?: throw IllegalStateException("无法写入所选位置")
        sourceFile.inputStream().use { input ->
            output.use { stream -> input.copyTo(stream) }
        }
    }

    private fun restoreDatabaseFromUri(uri: Uri, targetFile: File) {
        val parent = targetFile.parentFile ?: throw IllegalStateException("数据库目录不存在")
        if (!parent.exists() && !parent.mkdirs()) {
            throw IllegalStateException("无法创建数据库目录")
        }
        val tempFile = File(parent, "${targetFile.name}.restore.tmp")
        contentResolver.openInputStream(uri).use { input ->
            if (input == null) throw IllegalStateException("无法读取备份文件")
            tempFile.outputStream().use { output -> input.copyTo(output) }
        }
        if (!isGoToDoDatabase(tempFile)) {
            tempFile.delete()
            throw IllegalArgumentException("请选择有效的 GoToDo 备份文件")
        }

        deleteDatabaseSidecars(targetFile)
        if (targetFile.exists() && !targetFile.delete()) {
            tempFile.delete()
            throw IllegalStateException("无法替换当前数据库")
        }
        if (!tempFile.renameTo(targetFile)) {
            tempFile.copyTo(targetFile, overwrite = true)
            tempFile.delete()
        }
        deleteDatabaseSidecars(targetFile)
    }

    private fun isSqliteDatabase(file: File): Boolean {
        val expected = "SQLite format 3\u0000".toByteArray(Charsets.US_ASCII)
        val header = ByteArray(expected.size)
        val count = FileInputStream(file).use { input -> input.read(header) }
        return count == expected.size && header.contentEquals(expected)
    }

    private fun isGoToDoDatabase(file: File): Boolean {
        if (!isSqliteDatabase(file)) return false
        return try {
            val database = SQLiteDatabase.openDatabase(
                file.path,
                null,
                SQLiteDatabase.OPEN_READONLY
            )
            database.use { db ->
                val tableNames = mutableSetOf<String>()
                db.rawQuery(
                    "SELECT name FROM sqlite_master WHERE type = 'table'",
                    null
                ).use { cursor ->
                    while (cursor.moveToNext()) {
                        tableNames.add(cursor.getString(0))
                    }
                }
                tableNames.containsAll(
                    setOf("projects", "focus_sessions", "app_settings")
                )
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun deleteDatabaseSidecars(databaseFile: File) {
        File("${databaseFile.path}-wal").delete()
        File("${databaseFile.path}-shm").delete()
    }

    private fun unregisterTimerReceiver() {
        val receiver = timerReceiver ?: return
        unregisterReceiver(receiver)
        timerReceiver = null
    }

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 4201
        private const val BACKUP_CREATE_DOCUMENT_REQUEST = 4301
        private const val RESTORE_OPEN_DOCUMENT_REQUEST = 4302
    }
}
