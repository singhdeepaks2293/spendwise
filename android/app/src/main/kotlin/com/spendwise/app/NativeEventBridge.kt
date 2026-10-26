package com.spendwise.app

import android.app.Notification
import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.EventChannel

/** Checks the special notification-listener grant (not a runtime permission). */
object NotificationAccess {
    fun isGranted(context: Context): Boolean {
        val enabled = NotificationManagerCompat.getEnabledListenerPackages(context)
        return enabled.contains(context.packageName)
    }
}

/**
 * Single owner of the Dart EventChannel sink.
 *
 * Listener callbacks arrive on binder threads, so all sink writes are posted to
 * the main looper. If no sink is attached (app process not running), events are
 * persisted by [PendingEventStore] instead.
 */
object NativeEventBridge {
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var sink: EventChannel.EventSink? = null

    @Volatile
    var isListenerConnected: Boolean = false

    fun attach(events: EventChannel.EventSink?) {
        sink = events
    }

    fun detach() {
        sink = null
    }

    /**
     * Sends the event to Dart when the app is alive, otherwise queues it in
     * encrypted storage for the next resume.
     *
     * The queue fallback is applied inside the main-thread runnable as well as
     * when no sink exists: the engine can detach between the check and the
     * post, and silently dropping a payment alert would be worse than a
     * duplicate (the Dart repository dedupes by stable event id).
     */
    fun publish(context: Context, event: Map<String, Any?>) {
        val current = sink
        if (current == null) {
            PendingEventStore.append(context, event)
            return
        }
        mainHandler.post {
            try {
                current.success(event)
            } catch (_: Exception) {
                if (sink === current) sink = null
                PendingEventStore.append(context, event)
            }
        }
    }
}

/** Convenience for filtering group-summary notifications. */
fun Notification.isGroupSummary(): Boolean {
    return (flags and Notification.FLAG_GROUP_SUMMARY) != 0
}
