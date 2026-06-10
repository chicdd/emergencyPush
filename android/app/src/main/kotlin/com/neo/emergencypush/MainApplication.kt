package com.neo.emergencypush

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterEngineGroup

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        createEmergencyChannel()
    }

    private fun createEmergencyChannel() {
        val channel = NotificationChannel(
            "emergency_channel",
            "비상 상황",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "비상 상황 알림 — 무음/방해금지 모드에서도 소리 재생"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 500, 200, 500)
            // 알람 스트림 사용 → 무음/진동 모드 우회
            val audioAttr = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            setSound(Settings.System.DEFAULT_ALARM_ALERT_URI, audioAttr)
            // 방해 금지(DND) 모드 우회
            setBypassDnd(true)
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
}
