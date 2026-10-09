package com.kidyoh.waterly.widget

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * Today's drinks, the goal and cup sizes, read from and written to the
 * same storage the Flutter app uses (shared_preferences: the
 * "FlutterSharedPreferences" file, keys prefixed "flutter.", ints as
 * longs). Formats match lib/water_store.dart.
 */
class WaterData(context: Context) {
    private val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    val goal: Int
        get() = runCatching { prefs.getLong("flutter.goal", DEFAULT_GOAL.toLong()).toInt() }
            .getOrDefault(DEFAULT_GOAL)

    val cups: List<Int>
        get() {
            val raw = prefs.getString("flutter.cups", null) ?: return DEFAULT_CUPS
            if (!raw.startsWith(JSON_LIST_PREFIX)) return DEFAULT_CUPS
            return runCatching {
                val array = JSONArray(raw.substring(JSON_LIST_PREFIX.length))
                (0 until array.length()).map { array.getString(it).toInt() }
            }.getOrNull()?.takeIf { it.size == DEFAULT_CUPS.size } ?: DEFAULT_CUPS
        }

    fun todayTotal(): Int {
        val entries = entries(dayKey())
        return (0 until entries.length()).sumOf { entries.getJSONObject(it).optInt("a") }
    }

    /** Logs a drink now, newest first like the app. Returns the new total. */
    fun add(ml: Int): Int {
        val day = dayKey()
        val old = entries(day)
        val updated = JSONArray().put(JSONObject().put("a", ml).put("t", System.currentTimeMillis()))
        for (i in 0 until old.length()) updated.put(old.get(i))
        prefs.edit()
            .putString("flutter.entries_$day", updated.toString())
            .putLong("flutter.goal_$day", goal.toLong())
            .commit()
        return todayTotal()
    }

    private fun entries(day: String): JSONArray =
        runCatching { JSONArray(prefs.getString("flutter.entries_$day", "[]")) }.getOrDefault(JSONArray())

    companion object {
        const val DEFAULT_GOAL = 2000
        val DEFAULT_CUPS = listOf(150, 250)

        /** How shared_preferences_android marks a JSON-encoded string list. */
        private const val JSON_LIST_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!"

        /** Same as WaterStore.dayKey: "2026-10-07". */
        fun dayKey(calendar: Calendar = Calendar.getInstance()): String = "%04d-%02d-%02d".format(
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1,
            calendar.get(Calendar.DAY_OF_MONTH),
        )
    }
}
