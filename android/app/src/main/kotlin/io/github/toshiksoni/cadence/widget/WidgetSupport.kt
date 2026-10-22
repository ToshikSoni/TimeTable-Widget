package io.github.toshiksoni.cadence.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import io.github.toshiksoni.cadence.MainActivity
import io.github.toshiksoni.cadence.R
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale

internal fun loadPayload(context: Context): WidgetPayload? =
    WidgetPayload.parse(HomeWidgetPlugin.getData(context).getString(WidgetPayload.KEY, null))

internal fun launchAppIntent(context: Context): PendingIntent =
    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("cadence://today"))

/** Current widget height in dp, or 0 if the launcher has not reported it yet. */
internal fun widgetHeightDp(options: Bundle?): Int {
    if (options == null) return 0
    // Portrait launchers report the real height as MAX, landscape as MIN.
    val max = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
    val min = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
    return if (max > 0) max else min
}

enum class ColorRole(val light: Int, val dark: Int) {
    SURFACE(R.color.widget_surface_light, R.color.widget_surface_dark),
    ON_SURFACE(R.color.widget_on_surface_light, R.color.widget_on_surface_dark),
    ON_SURFACE_VARIANT(R.color.widget_on_surface_variant_light, R.color.widget_on_surface_variant_dark),
    ON_SURFACE_DIM(R.color.widget_on_surface_dim_light, R.color.widget_on_surface_dim_dark),
    TRACK(R.color.widget_track_light, R.color.widget_track_dark),
}

/**
 * Applies colours according to the theme picked in the app. For "system" on Android 12+ both
 * variants go into the RemoteViews so the launcher can switch without waiting for an update.
 */
internal class WidgetPalette(private val context: Context, private val theme: WidgetTheme, accent: Int) {
    private val accentLight = accent or 0xFF000000.toInt()
    private val accentDark = blend(accentLight, 0xFFFFFFFF.toInt(), 0.35f)

    private val systemIsNight: Boolean
        get() = context.resources.configuration.uiMode and
            Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES

    val isDarkNow: Boolean
        get() = when (theme) {
            WidgetTheme.LIGHT -> false
            WidgetTheme.DARK -> true
            WidgetTheme.SYSTEM -> systemIsNight
        }

    fun color(views: RemoteViews, id: Int, method: String, role: ColorRole) =
        pair(views, id, method, context.getColor(role.light), context.getColor(role.dark))

    fun accent(views: RemoteViews, id: Int, method: String) =
        pair(views, id, method, accentLight, accentDark)

    fun text(views: RemoteViews, id: Int, role: ColorRole) = color(views, id, "setTextColor", role)

    fun accentText(views: RemoteViews, id: Int) = accent(views, id, "setTextColor")

    /** Tints the progress bar; older launchers keep the drawable's built-in colours. */
    fun progress(views: RemoteViews, id: Int) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val trackLight = ColorStateList.valueOf(context.getColor(ColorRole.TRACK.light))
        val trackDark = ColorStateList.valueOf(context.getColor(ColorRole.TRACK.dark))
        val fillLight = ColorStateList.valueOf(accentLight)
        val fillDark = ColorStateList.valueOf(accentDark)
        when (theme) {
            WidgetTheme.LIGHT -> {
                views.setColorStateList(id, "setProgressTintList", fillLight)
                views.setColorStateList(id, "setProgressBackgroundTintList", trackLight)
            }
            WidgetTheme.DARK -> {
                views.setColorStateList(id, "setProgressTintList", fillDark)
                views.setColorStateList(id, "setProgressBackgroundTintList", trackDark)
            }
            WidgetTheme.SYSTEM -> {
                views.setColorStateList(id, "setProgressTintList", fillLight, fillDark)
                views.setColorStateList(id, "setProgressBackgroundTintList", trackLight, trackDark)
            }
        }
    }

    private fun pair(views: RemoteViews, id: Int, method: String, light: Int, dark: Int) {
        when (theme) {
            WidgetTheme.LIGHT -> views.setInt(id, method, light)
            WidgetTheme.DARK -> views.setInt(id, method, dark)
            WidgetTheme.SYSTEM ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    views.setColorInt(id, method, light, dark)
                } else {
                    views.setInt(id, method, if (systemIsNight) dark else light)
                }
        }
    }

    private companion object {
        fun blend(from: Int, to: Int, ratio: Float): Int {
            fun channel(shift: Int): Int {
                val a = (from shr shift) and 0xFF
                val b = (to shr shift) and 0xFF
                return (a + (b - a) * ratio).toInt() and 0xFF
            }
            return (0xFF shl 24) or (channel(16) shl 16) or (channel(8) shl 8) or channel(0)
        }
    }
}

/** User-facing strings derived from times. */
internal class WidgetFormatter(private val context: Context, use24h: Boolean, private val zone: ZoneId) {
    private val locale: Locale = context.resources.configuration.locales[0]
    private val timeFormat = DateTimeFormatter.ofPattern(if (use24h) "HH:mm" else "h:mm a", locale)
    private val headerDateFormat = DateTimeFormatter.ofPattern("EEEE, d MMM", locale)
    private val weekdayFormat = DateTimeFormatter.ofPattern("EEEE", locale)
    private val shortDateFormat = DateTimeFormatter.ofPattern("EEE, d MMM", locale)

    fun time(epochMs: Long): String = Instant.ofEpochMilli(epochMs).atZone(zone).format(timeFormat)

    fun headerDate(date: LocalDate): String = date.format(headerDateFormat)

    /** "Tomorrow", a weekday within the next week, or a short date beyond that. */
    fun dayLabel(date: LocalDate, today: LocalDate): String {
        val days = ChronoUnit.DAYS.between(today, date)
        return when {
            days == 1L -> context.getString(R.string.widget_tomorrow)
            days in 2..6 -> date.format(weekdayFormat)
            else -> date.format(shortDateFormat)
        }
    }

    fun duration(minutes: Long): String {
        val m = minutes.coerceAtLeast(1)
        val hours = m / 60
        val rest = m % 60
        return when {
            hours == 0L -> context.getString(R.string.widget_duration_minutes, m)
            rest == 0L || hours >= 3 ->
                context.getString(R.string.widget_duration_hours, if (rest >= 30) hours + 1 else hours)
            else -> context.getString(R.string.widget_duration_hours_minutes, hours, rest)
        }
    }

    fun startsIn(minutes: Long): String =
        if (minutes <= 0) context.getString(R.string.widget_starting_now)
        else context.getString(R.string.widget_in, duration(minutes))

    /** "Tomorrow · 09:30 · Cloud Security" */
    fun nextDayLine(event: WidgetEvent, today: LocalDate): String {
        val date = WidgetState.localDate(event.start, zone)
        return joinDot(dayLabel(date, today), time(event.start), event.title)
    }

    fun location(event: WidgetEvent): String =
        joinDot(event.room, event.teacher).ifEmpty { event.code }

    fun joinDot(vararg parts: String): String =
        parts.filter { it.isNotBlank() }.joinToString(context.getString(R.string.widget_separator))
}
