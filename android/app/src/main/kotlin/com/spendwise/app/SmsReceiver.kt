package com.spendwise.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Captures live bank SMS while the app is installed.
 *
 * Multipart messages are reassembled before filtering. Only alerts from a bank
 * sender ID (or a numeric sender that explicitly mentions an account/card) are
 * published; personal SMS never leave the provider.
 */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        val grouped = LinkedHashMap<String, MutableList<android.telephony.SmsMessage>>()
        for (part in parts) {
            val address = part.originatingAddress ?: continue
            val key = "$address:${part.timestampMillis}"
            grouped.getOrPut(key) { ArrayList() }.add(part)
        }

        for ((_, messages) in grouped) {
            val first = messages.firstOrNull() ?: continue
            val address = first.originatingAddress ?: continue
            val body = messages.mapNotNull { it.messageBody }.joinToString("")
            if (!FinancialMessageFilter.looksFinancial(body)) continue
            if (!FinancialMessageFilter.isBankSender(address, body)) continue

            val timestamp = first.timestampMillis.takeIf { it > 0 }
                ?: System.currentTimeMillis()
            val event = mapOf(
                "type" to "sms",
                "id" to "live-$timestamp-${address.hashCode()}-${body.hashCode()}",
                "address" to address,
                "body" to body,
                "date" to timestamp,
            )
            NativeEventBridge.publish(context.applicationContext, event)
        }
    }
}
