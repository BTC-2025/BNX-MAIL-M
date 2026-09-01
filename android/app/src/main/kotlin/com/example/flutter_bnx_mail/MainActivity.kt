package com.example.flutter_bnx_mail

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.bnxmail.app/notifications"
    private val NOTIFICATION_CHANNEL_ID = "bnx_mail_new_email"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "createNotificationChannel" -> {
                    createNotificationChannel()
                    result.success(true)
                }
                "showNotification" -> {
                    val id = call.argument<Int>("id") ?: 1001
                    val title = call.argument<String>("title") ?: "BNX Mail"
                    val subject = call.argument<String>("subject") ?: "New email"
                    val preview = call.argument<String>("preview") ?: ""
                    val emailId = call.argument<String>("emailId") ?: ""
                    val accountEmail = call.argument<String>("accountEmail") ?: ""

                    showSystemNotification(id, title, subject, preview, emailId, accountEmail)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "BNX Mail"
            val descriptionText = "New email notifications"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableVibration(true)
                setShowBadge(true)
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun showSystemNotification(id: Int, title: String, subject: String, preview: String, emailId: String, accountEmail: String) {
        createNotificationChannel()

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("emailId", emailId)
            putExtra("accountEmail", accountEmail)
        }
        val pendingIntent = PendingIntent.getActivity(
            this, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentTitle(title)
            .setContentText(subject)
            .setStyle(NotificationCompat.BigTextStyle().bigText("$subject\n$preview"))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(id, builder.build())
    }
}

