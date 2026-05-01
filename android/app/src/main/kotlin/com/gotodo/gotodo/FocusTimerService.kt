package com.gotodo.gotodo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import kotlin.math.max

class FocusTimerService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var projectName = "专注中"
    private var mode = MODE_COUNT_UP
    private var startAtMillis = 0L
    private var plannedSeconds = 0
    private var pauseSeconds = 0
    private var lastPausedAtMillis: Long? = null
    private var soundEnabled = true
    private var vibrationEnabled = true
    private var running = false

    private val ticker = object : Runnable {
        override fun run() {
            if (!running) return
            if (mode == MODE_COUNT_DOWN && remainingSeconds() <= 0) {
                finishCountdown()
                return
            }
            updateNotification()
            sendTimerEvent("running")
            handler.postDelayed(this, 1000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startTimer(intent)
            ACTION_PAUSE -> pauseTimer()
            ACTION_RESUME -> resumeTimer()
            ACTION_STOP -> stopTimer()
            ACTION_COMPLETE -> finishCountdown()
        }
        return START_STICKY
    }

    private fun startTimer(intent: Intent) {
        projectName = intent.getStringExtra(EXTRA_PROJECT_NAME) ?: "专注中"
        mode = intent.getStringExtra(EXTRA_MODE) ?: MODE_COUNT_UP
        startAtMillis = intent.getLongExtra(
            EXTRA_START_AT_MILLIS,
            System.currentTimeMillis()
        )
        plannedSeconds = intent.getIntExtra(EXTRA_PLANNED_SECONDS, 0)
        soundEnabled = intent.getBooleanExtra(EXTRA_SOUND_ENABLED, true)
        vibrationEnabled = intent.getBooleanExtra(EXTRA_VIBRATION_ENABLED, true)
        pauseSeconds = 0
        lastPausedAtMillis = null
        running = true

        createNotificationChannels()
        startForeground(NOTIFICATION_ID, buildNotification("running"))
        handler.removeCallbacks(ticker)
        handler.post(ticker)
        sendTimerEvent("running")
    }

    private fun pauseTimer() {
        if (!running) return
        running = false
        lastPausedAtMillis = System.currentTimeMillis()
        handler.removeCallbacks(ticker)
        updateNotification("paused")
        sendTimerEvent("paused")
    }

    private fun resumeTimer() {
        val pausedAt = lastPausedAtMillis
        if (running || pausedAt == null) return
        pauseSeconds += max(0, ((System.currentTimeMillis() - pausedAt) / 1000).toInt())
        lastPausedAtMillis = null
        running = true
        updateNotification("running")
        handler.post(ticker)
        sendTimerEvent("running")
    }

    private fun stopTimer() {
        running = false
        handler.removeCallbacks(ticker)
        sendTimerEvent("stopped")
        stopForegroundCompat()
        stopSelf()
    }

    private fun finishCountdown() {
        running = false
        handler.removeCallbacks(ticker)
        playCompletionSound()
        vibrateCompletion()
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(DONE_NOTIFICATION_ID, buildNotification("completed"))
        sendTimerEvent("completed")
        stopForegroundCompat()
        stopSelf()
    }

    private fun updateNotification(status: String = if (running) "running" else "paused") {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification(status))
    }

    private fun buildNotification(status: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val channelId = if (status == "completed") DONE_CHANNEL_ID else CHANNEL_ID
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            Notification.Builder(this)
        }
        val text = when (status) {
            "paused" -> "已暂停 · ${formatSeconds(elapsedSeconds())}"
            "completed" -> "倒计时已结束"
            else -> if (mode == MODE_COUNT_DOWN) {
                "剩余 ${formatSeconds(remainingSeconds())}"
            } else {
                "已专注 ${formatSeconds(elapsedSeconds())}"
            }
        }
        return builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(projectName)
            .setContentText(text)
            .setContentIntent(pendingIntent)
            .setOngoing(status != "completed")
            .setAutoCancel(status == "completed")
            .setPriority(
                if (status == "completed") {
                    Notification.PRIORITY_HIGH
                } else {
                    Notification.PRIORITY_LOW
                }
            )
            .setCategory(
                if (status == "completed") {
                    Notification.CATEGORY_ALARM
                } else {
                    Notification.CATEGORY_STATUS
                }
            )
            .setOnlyAlertOnce(status != "completed")
            .build()
    }

    private fun elapsedSeconds(): Int {
        val now = lastPausedAtMillis ?: System.currentTimeMillis()
        return max(0, ((now - startAtMillis) / 1000).toInt() - pauseSeconds)
    }

    private fun remainingSeconds(): Int {
        if (mode != MODE_COUNT_DOWN) return 0
        return max(0, plannedSeconds - elapsedSeconds())
    }

    private fun sendTimerEvent(status: String) {
        val intent = Intent(ACTION_TIMER_EVENT).apply {
            setPackage(packageName)
            putExtra("status", status)
            putExtra("elapsedSeconds", elapsedSeconds())
            putExtra("remainingSeconds", remainingSeconds())
        }
        sendBroadcast(intent)
    }

    private fun playCompletionSound() {
        if (!soundEnabled) return
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val ringtone = RingtoneManager.getRingtone(applicationContext, uri)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                ringtone.audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            }
            ringtone.play()
        } catch (_: Exception) {
            // Some devices block direct playback in DND or silent modes.
        }
    }

    @Suppress("DEPRECATION")
    private fun vibrateCompletion() {
        if (!vibrationEnabled) return
        try {
            val pattern = longArrayOf(0, 350, 120, 350)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager = getSystemService(VibratorManager::class.java)
                manager.defaultVibrator.vibrate(
                    VibrationEffect.createWaveform(pattern, -1)
                )
            } else {
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
                } else {
                    vibrator.vibrate(pattern, -1)
                }
            }
        } catch (_: Exception) {
            // Vibration can be disabled by device policy or system settings.
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val timerChannel = NotificationChannel(
            CHANNEL_ID,
            "GoToDo 计时",
            NotificationManager.IMPORTANCE_LOW
        )
        timerChannel.description = "专注计时进行中"

        val doneChannel = NotificationChannel(
            DONE_CHANNEL_ID,
            "GoToDo 倒计时完成",
            NotificationManager.IMPORTANCE_HIGH
        )
        doneChannel.description = "倒计时结束提醒"
        doneChannel.setSound(null, null)
        doneChannel.enableVibration(false)

        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(timerChannel)
        manager.createNotificationChannel(doneChannel)
    }

    @Suppress("DEPRECATION")
    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
    }

    private fun formatSeconds(totalSeconds: Int): String {
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60
        return if (hours > 0) {
            "%d:%02d:%02d".format(hours, minutes, seconds)
        } else {
            "%d:%02d".format(minutes, seconds)
        }
    }

    companion object {
        const val ACTION_START = "com.gotodo.gotodo.timer.START"
        const val ACTION_PAUSE = "com.gotodo.gotodo.timer.PAUSE"
        const val ACTION_RESUME = "com.gotodo.gotodo.timer.RESUME"
        const val ACTION_STOP = "com.gotodo.gotodo.timer.STOP"
        const val ACTION_COMPLETE = "com.gotodo.gotodo.timer.COMPLETE"
        const val ACTION_TIMER_EVENT = "com.gotodo.gotodo.timer.EVENT"

        const val EXTRA_PROJECT_NAME = "projectName"
        const val EXTRA_MODE = "mode"
        const val EXTRA_START_AT_MILLIS = "startAtMillis"
        const val EXTRA_PLANNED_SECONDS = "plannedSeconds"
        const val EXTRA_SOUND_ENABLED = "soundEnabled"
        const val EXTRA_VIBRATION_ENABLED = "vibrationEnabled"

        private const val CHANNEL_ID = "gotodo_timer"
        private const val DONE_CHANNEL_ID = "gotodo_timer_done_silent_v1"
        private const val NOTIFICATION_ID = 1001
        private const val DONE_NOTIFICATION_ID = 1002
        private const val MODE_COUNT_UP = "count_up"
        private const val MODE_COUNT_DOWN = "count_down"
    }
}
