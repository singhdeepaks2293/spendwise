package com.spendwise.app

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Reads payment notifications from apps the user has explicitly granted access
 * to. Content is filtered natively, then either streamed to Flutter or queued in
 * encrypted storage if the app process is gone.
 */
class SpendwiseNotificationListener : NotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()
        NativeEventBridge.isListenerConnected = true
    }

    override fun onListenerDisconnected() {
        NativeEventBridge.isListenerConnected = false
        super.onListenerDisconnected()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val notification = sbn?.notification ?: return
        if (notification.isGroupSummary()) return

        val packageName = sbn.packageName ?: return
        val extras = notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString().orEmpty()
        val body = listOf(title, text, bigText)
            .filter { it.isNotBlank() }
            .distinct()
            .joinToString("\n")

        if (!FinancialMessageFilter.isNotificationCandidate(packageName, body)) return

        val appName = resolveAppName(packageName)
        val event = mapOf(
            "type" to "notification",
            "key" to (sbn.key ?: "$packageName:${sbn.id}:${sbn.postTime}"),
            "packageName" to packageName,
            "appName" to appName,
            "title" to title,
            "text" to text,
            "bigText" to bigText,
            "postTime" to sbn.postTime,
        )
        NativeEventBridge.publish(applicationContext, event)
    }

    private fun resolveAppName(packageName: String): String {
        return try {
            val info = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: Exception) {
            packageName
        }
    }
}
