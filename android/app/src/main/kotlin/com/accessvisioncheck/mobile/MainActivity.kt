package com.accessvisioncheck.mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "ACCESS alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Documentation requests, assignments, and announcements"
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
        super.onCreate(savedInstanceState)
    }

    companion object {
        const val CHANNEL_ID = "access_alerts"
    }
}
