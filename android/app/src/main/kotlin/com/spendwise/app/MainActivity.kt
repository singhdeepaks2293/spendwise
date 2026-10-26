package com.spendwise.app

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

/**
 * Hosts the Flutter engine and exposes the on-device ingestion APIs.
 *
 * Every method is deliberately narrow: the Dart side never asks for arbitrary
 * content providers, and notification/SMS payloads are filtered natively before
 * they cross the platform channel.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NATIVE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasNotificationAccess" -> {
                    result.success(NotificationAccess.isGranted(this))
                }

                "isNotificationListenerConnected" -> {
                    result.success(NativeEventBridge.isListenerConnected)
                }

                "openNotificationSettings" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(null)
                    } catch (error: Exception) {
                        result.error(
                            "settings_unavailable",
                            "Could not open notification access settings.",
                            error.message,
                        )
                    }
                }

                "readSmsInbox" -> {
                    val beforeMillis = call.argument<Number>("beforeMillis")?.toLong()
                    val beforeId = call.argument<String>("beforeId")
                    val limit = call.argument<Number>("limit")?.toInt() ?: 500
                    try {
                        result.success(
                            SmsReader.read(this, beforeMillis, beforeId, limit),
                        )
                    } catch (error: SecurityException) {
                        result.error(
                            "permission_denied",
                            "SMS permission is required to read transaction alerts.",
                            null,
                        )
                    } catch (error: Exception) {
                        result.error(
                            "sms_read_failed",
                            "Could not read SMS messages.",
                            error.message,
                        )
                    }
                }

                "getSmsCount" -> {
                    try {
                        result.success(SmsReader.count(this))
                    } catch (_: SecurityException) {
                        result.error(
                            "permission_denied",
                            "SMS permission is required to read transaction alerts.",
                            null,
                        )
                    } catch (_: Exception) {
                        result.success(0)
                    }
                }

                "drainPendingEvents" -> {
                    result.success(PendingEventStore.drain(this))
                }

                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NativeEventBridge.attach(events)
                }

                override fun onCancel(arguments: Any?) {
                    NativeEventBridge.detach()
                }
            },
        )

        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "transactionFeedNative",
            TransactionFeedNativeAdFactory(this),
        )
    }

    override fun onDestroy() {
        NativeEventBridge.detach()
        super.onDestroy()
    }

    companion object {
        const val NATIVE_CHANNEL = "com.spendwise.app/native"
        const val EVENT_CHANNEL = "com.spendwise.app/events"
    }
}
