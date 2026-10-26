package com.spendwise.app

import android.content.Context
import android.provider.Telephony

/**
 * Paginated, newest-first reader for the SMS inbox.
 *
 * Rows are returned unfiltered so Dart can apply the bank-sender policy and
 * report accurate paging progress. The query is bounded by the composite
 * cursor ([beforeMillis], [beforeId]) and [limit] and never leaves the device.
 * The id tie-breaker is required because bulk bank alerts can share the same
 * millisecond timestamp; paging on time alone would skip messages.
 */
object SmsReader {
    private val projection = arrayOf(
        Telephony.Sms._ID,
        Telephony.Sms.ADDRESS,
        Telephony.Sms.BODY,
        Telephony.Sms.DATE,
    )

    fun read(
        context: Context,
        beforeMillis: Long?,
        beforeId: String?,
        limit: Int,
    ): List<Map<String, Any?>> {
        val pageSize = limit.coerceIn(1, 1000)
        val beforeRowId = beforeId?.toLongOrNull()
        val hasTimeCursor = beforeMillis != null && beforeMillis > 0
        val hasCompositeCursor = hasTimeCursor && beforeRowId != null

        val selection = when {
            hasCompositeCursor ->
                "(${Telephony.Sms.DATE} < ?) OR " +
                    "(${Telephony.Sms.DATE} = ? AND ${Telephony.Sms._ID} < ?)"
            hasTimeCursor -> "${Telephony.Sms.DATE} < ?"
            else -> null
        }
        val selectionArgs = when {
            hasCompositeCursor -> arrayOf(
                beforeMillis.toString(),
                beforeMillis.toString(),
                beforeRowId.toString(),
            )
            hasTimeCursor -> arrayOf(beforeMillis.toString())
            else -> null
        }

        val results = ArrayList<Map<String, Any?>>(pageSize)
        context.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            "${Telephony.Sms.DATE} DESC, ${Telephony.Sms._ID} DESC",
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(Telephony.Sms._ID)
            val addressIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val bodyIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val dateIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)

            while (cursor.moveToNext() && results.size < pageSize) {
                val body = cursor.getString(bodyIndex) ?: continue
                if (body.isBlank()) continue
                results.add(
                    mapOf(
                        "type" to "sms",
                        "id" to cursor.getLong(idIndex).toString(),
                        "address" to (cursor.getString(addressIndex) ?: ""),
                        "body" to body,
                        "date" to cursor.getLong(dateIndex),
                    ),
                )
            }
        }
        return results
    }

    fun count(context: Context): Int {
        context.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            arrayOf(Telephony.Sms._ID),
            null,
            null,
            null,
        )?.use { cursor ->
            return cursor.count
        }
        return 0
    }
}
