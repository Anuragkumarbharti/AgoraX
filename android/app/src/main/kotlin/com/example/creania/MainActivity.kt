package com.example.creania

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channels = listOf(
                NotificationChannelInfo(
                    "messages_channel",
                    "Messages",
                    "Direct and group chat messages",
                    NotificationManager.IMPORTANCE_HIGH
                ),
                NotificationChannelInfo(
                    "voice_rooms_channel",
                    "Voice Rooms",
                    "Voice room invites and events",
                    NotificationManager.IMPORTANCE_DEFAULT
                ),
                NotificationChannelInfo(
                    "community_channel",
                    "Community",
                    "Community posts and updates",
                    NotificationManager.IMPORTANCE_DEFAULT
                ),
                NotificationChannelInfo(
                    "wallet_channel",
                    "Wallet",
                    "Transactions and coin alerts",
                    NotificationManager.IMPORTANCE_HIGH
                ),
                NotificationChannelInfo(
                    "quiz_channel",
                    "Quiz",
                    "Quiz alerts and rewards",
                    NotificationManager.IMPORTANCE_DEFAULT
                ),
                NotificationChannelInfo(
                    "system_channel",
                    "System",
                    "Security alerts and system notices",
                    NotificationManager.IMPORTANCE_HIGH
                ),
                NotificationChannelInfo(
                    "marketing_channel",
                    "Marketing",
                    "Promotional and marketing updates",
                    NotificationManager.IMPORTANCE_LOW
                )
            )

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            for (chInfo in channels) {
                val channel = NotificationChannel(chInfo.id, chInfo.name, chInfo.importance).apply {
                    description = chInfo.description
                    enableVibration(true)
                }
                manager.createNotificationChannel(channel)
            }
        }
    }

    data class NotificationChannelInfo(
        val id: String,
        val name: String,
        val description: String,
        val importance: Int
    )
}
