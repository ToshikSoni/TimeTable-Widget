package io.github.toshiksoni.cadence.dnd

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray

/**
 * Turns Do Not Disturb on while activities marked "silence my phone" run, and
 * back off afterwards.
 *
 * The Flutter side hands over the upcoming windows; from then on everything
 * runs natively off AlarmManager, so it keeps working when the app is closed.
 * DND is only switched off again if Cadence was the one that switched it on,
 * so a manual or scheduled DND set by the user is never cancelled.
 */
object DndScheduler {
    private const val PREFS = "cadence_dnd"
    private const val KEY_WINDOWS = "windows"
    private const val KEY_APPLIED = "applied"
    private const val REQUEST_CODE = 0xD0D

    fun hasAccess(context: Context): Boolean =
        notificationManager(context).isNotificationPolicyAccessGranted

    /** [windows] holds pairs of epoch milliseconds: start, end. */
    fun schedule(context: Context, windows: List<LongArray>) {
        val json = JSONArray()
        windows.filter { it.size == 2 && it[1] > it[0] }.forEach {
            json.put(JSONArray().put(it[0]).put(it[1]))
        }
        prefs(context).edit().putString(KEY_WINDOWS, json.toString()).apply()
        apply(context)
    }

    /** Brings DND in line with the current time and arms the next change. */
    fun apply(context: Context) {
        val now = System.currentTimeMillis()
        val windows = loadWindows(context).filter { it[1] > now }
        val inside = windows.any { it[0] <= now && now < it[1] }
        val nm = notificationManager(context)
        val prefs = prefs(context)

        if (hasAccess(context)) {
            val applied = prefs.getBoolean(KEY_APPLIED, false)
            val current = nm.currentInterruptionFilter
            if (inside && !applied && current == NotificationManager.INTERRUPTION_FILTER_ALL) {
                // Priority mode still lets alarms (including Cadence's) through.
                nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                prefs.edit().putBoolean(KEY_APPLIED, true).apply()
            } else if (!inside && applied) {
                if (current == NotificationManager.INTERRUPTION_FILTER_PRIORITY) {
                    nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                }
                prefs.edit().putBoolean(KEY_APPLIED, false).apply()
            }
        }

        val next = windows.flatMap { listOf(it[0], it[1]) }.filter { it > now }.minOrNull()
        arm(context, next)
    }

    private fun arm(context: Context, at: Long?) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            Intent(context, DndReceiver::class.java).setAction(DndReceiver.ACTION_TICK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarms.cancel(intent)
        if (at == null) return
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()
        if (exact) {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent)
        } else {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent)
        }
    }

    private fun loadWindows(context: Context): List<LongArray> {
        val raw = prefs(context).getString(KEY_WINDOWS, null) ?: return emptyList()
        return try {
            val json = JSONArray(raw)
            (0 until json.length()).map {
                val pair = json.getJSONArray(it)
                longArrayOf(pair.getLong(0), pair.getLong(1))
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun notificationManager(context: Context) =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}
