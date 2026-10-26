package com.spendwise.app

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import org.json.JSONArray
import org.json.JSONObject

/**
 * Encrypted queue for SMS/notification events captured while Flutter was not
 * running.
 *
 * The payload may contain financial alerts, so it uses
 * EncryptedSharedPreferences with an AES-256-GCM key from the Android keystore.
 * If the keystore is unavailable (for example on a broken OEM build), the store
 * degrades to private app preferences rather than crashing ingestion.
 */
object PendingEventStore {
    private const val PREFS_NAME = "spendwise_pending_events_v1"
    private const val EVENTS_KEY = "events"
    private const val MAX_EVENTS = 500

    private val lock = Any()

    @Volatile
    private var cachedEncrypted: SharedPreferences? = null

    private fun preferences(context: Context): SharedPreferences {
        cachedEncrypted?.let { return it }
        val appContext = context.applicationContext
        return try {
            val masterKey = MasterKey.Builder(appContext)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()
            EncryptedSharedPreferences.create(
                appContext,
                PREFS_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            ).also { cachedEncrypted = it }
        } catch (_: Exception) {
            // Do not cache the plaintext fallback: retry the keystore-backed
            // store on the next event in case the failure was transient.
            context.applicationContext.getSharedPreferences(
                PREFS_NAME,
                Context.MODE_PRIVATE,
            )
        }
    }

    fun append(context: Context, event: Map<String, Any?>) {
        synchronized(lock) {
            val prefs = preferences(context)
            val existing = readArray(prefs.getString(EVENTS_KEY, null))
            val dedupeKey = dedupeKey(event)

            val kept = ArrayList<JSONObject>(existing.length() + 1)
            for (index in 0 until existing.length()) {
                val item = existing.optJSONObject(index) ?: continue
                if (dedupeKey != null && dedupeKey(item) == dedupeKey) continue
                kept.add(item)
            }
            kept.add(toJson(event))
            while (kept.size > MAX_EVENTS) {
                kept.removeAt(0)
            }

            val array = JSONArray()
            kept.forEach { array.put(it) }
            // commit() is deliberate: this store exists to survive process
            // death, so an asynchronous apply() could lose the alert.
            prefs.edit().putString(EVENTS_KEY, array.toString()).commit()
        }
    }

    /** Returns queued events oldest-first and clears the queue atomically. */
    fun drain(context: Context): List<Map<String, Any?>> {
        synchronized(lock) {
            val prefs = preferences(context)
            val array = readArray(prefs.getString(EVENTS_KEY, null))
            // commit() keeps the drain durable. If the write fails we still
            // return the events; the repository's idempotent dedupe makes a
            // later re-delivery harmless, whereas dropping them would not be.
            prefs.edit().remove(EVENTS_KEY).commit()

            val events = ArrayList<Map<String, Any?>>(array.length())
            for (index in 0 until array.length()) {
                val item = array.optJSONObject(index) ?: continue
                events.add(toMap(item))
            }
            return events
        }
    }

    private fun readArray(raw: String?): JSONArray {
        if (raw.isNullOrBlank()) return JSONArray()
        return try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
    }

    private fun dedupeKey(event: Map<String, Any?>): String? {
        return when (event["type"]) {
            "sms" -> event["id"]?.let { "sms:$it" }
            "notification" -> event["key"]?.let { "notification:$it" }
            else -> null
        }
    }

    private fun dedupeKey(item: JSONObject): String? {
        return when (item.optString("type")) {
            "sms" -> item.optString("id").takeIf { it.isNotEmpty() }?.let { "sms:$it" }
            "notification" ->
                item.optString("key").takeIf { it.isNotEmpty() }?.let { "notification:$it" }
            else -> null
        }
    }

    private fun toJson(event: Map<String, Any?>): JSONObject {
        val json = JSONObject()
        event.forEach { (key, value) -> json.put(key, value ?: JSONObject.NULL) }
        return json
    }

    private fun toMap(item: JSONObject): Map<String, Any?> {
        val map = LinkedHashMap<String, Any?>()
        val keys = item.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = item.opt(key)
            map[key] = when (value) {
                JSONObject.NULL -> null
                is JSONObject -> toMap(value)
                is JSONArray -> {
                    val list = ArrayList<Any?>(value.length())
                    for (index in 0 until value.length()) {
                        list.add(value.opt(index))
                    }
                    list
                }
                else -> value
            }
        }
        return map
    }
}
