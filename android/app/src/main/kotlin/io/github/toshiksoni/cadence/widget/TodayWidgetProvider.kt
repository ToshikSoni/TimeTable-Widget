package io.github.toshiksoni.cadence.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import io.github.toshiksoni.cadence.R
import java.time.ZoneId

/** Today's agenda: past classes dimmed, the current one highlighted. */
class TodayWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val payload = WidgetPayload.parse(widgetData.getString(WidgetPayload.KEY, null))
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, build(context, payload, appWidgetManager.getAppWidgetOptions(id)))
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        appWidgetManager.updateAppWidget(appWidgetId, build(context, loadPayload(context), newOptions))
    }

    private fun build(context: Context, payload: WidgetPayload?, options: Bundle?): RemoteViews {
        val zone = ZoneId.systemDefault()
        val now = System.currentTimeMillis()
        val model = WidgetState.today(payload, now, zone)
        val format = WidgetFormatter(context, payload?.use24h ?: true, zone)
        val palette = WidgetPalette(
            context,
            payload?.theme ?: WidgetTheme.SYSTEM,
            payload?.accent ?: WidgetPayload.DEFAULT_ACCENT,
        )

        val views = RemoteViews(context.packageName, R.layout.widget_today)
        views.setOnClickPendingIntent(android.R.id.background, launchAppIntent(context))
        palette.color(views, R.id.widget_surface, "setColorFilter", ColorRole.SURFACE)
        palette.text(views, R.id.today_date, ColorRole.ON_SURFACE)
        palette.accentText(views, R.id.today_chip)
        palette.text(views, R.id.today_timetable, ColorRole.ON_SURFACE_VARIANT)
        palette.accentText(views, R.id.today_banner)
        palette.text(views, R.id.today_more, ColorRole.ON_SURFACE_VARIANT)
        palette.text(views, R.id.today_empty_title, ColorRole.ON_SURFACE)
        palette.text(views, R.id.today_empty_subtitle, ColorRole.ON_SURFACE_VARIANT)
        palette.text(views, R.id.today_hint, ColorRole.ON_SURFACE_DIM)

        views.setTextViewText(R.id.today_date, format.headerDate(model.today))
        views.setTextOrGone(
            R.id.today_chip,
            when {
                model.rows.isEmpty() -> null
                model.remaining == 0 -> context.getString(R.string.widget_all_done)
                else -> context.getString(R.string.widget_left_count, model.remaining)
            },
        )
        views.setTextOrGone(R.id.today_timetable, payload?.timetable)
        views.setTextOrGone(R.id.today_banner, model.banner)
        views.setViewVisibility(R.id.today_hint, if (model.stale) View.VISIBLE else View.GONE)

        views.removeAllViews(R.id.today_rows)
        if (model.rows.isEmpty()) {
            views.setViewVisibility(R.id.today_rows, View.GONE)
            views.setViewVisibility(R.id.today_more, View.GONE)
            views.setViewVisibility(R.id.today_empty, View.VISIBLE)
            if (payload == null) {
                views.setTextViewText(R.id.today_empty_title, context.getString(R.string.widget_no_classes))
                views.setTextOrGone(R.id.today_empty_subtitle, context.getString(R.string.widget_tap_to_open))
            } else {
                views.setTextViewText(R.id.today_empty_title, context.getString(R.string.widget_free_day))
                views.setTextOrGone(
                    R.id.today_empty_subtitle,
                    model.nextDay?.let { context.getString(R.string.widget_next_up, format.nextDayLine(it, model.today)) },
                )
            }
            return views
        }

        views.setViewVisibility(R.id.today_empty, View.GONE)
        views.setViewVisibility(R.id.today_rows, View.VISIBLE)

        val window = visibleWindow(model, rowCapacity(context, model, payload, options))
        for (row in window) {
            views.addView(R.id.today_rows, buildRow(context, row, format, palette))
        }
        val hidden = model.rows.size - window.size
        views.setTextOrGone(R.id.today_more, if (hidden > 0) context.getString(R.string.widget_more, hidden) else null)
        return views
    }

    private fun buildRow(context: Context, row: TodayRow, format: WidgetFormatter, palette: WidgetPalette): RemoteViews {
        val event = row.event
        val views = RemoteViews(context.packageName, R.layout.widget_today_row)
        views.setTextViewText(R.id.row_start, format.time(event.start))
        views.setTextViewText(R.id.row_end, format.time(event.end))
        views.setTextViewText(R.id.row_title, event.title)
        views.setTextOrGone(
            R.id.row_room,
            if (event.kind == EventKind.EXAM) {
                format.joinDot(context.getString(R.string.widget_exam), event.room)
            } else {
                event.room.ifBlank { event.code }
            },
        )
        views.setInt(R.id.row_bar, "setColorFilter", event.color or OPAQUE)

        when (row.status) {
            RowStatus.PAST -> {
                for (id in TEXT_IDS) palette.text(views, id, ColorRole.ON_SURFACE_DIM)
                views.setInt(R.id.row_bar, "setImageAlpha", PAST_BAR_ALPHA)
            }
            RowStatus.CURRENT -> {
                views.setViewVisibility(R.id.row_highlight, View.VISIBLE)
                palette.accent(views, R.id.row_highlight, "setColorFilter")
                views.setInt(R.id.row_highlight, "setImageAlpha", if (palette.isDarkNow) 56 else 36)
                palette.accentText(views, R.id.row_start)
                palette.text(views, R.id.row_end, ColorRole.ON_SURFACE_VARIANT)
                palette.text(views, R.id.row_title, ColorRole.ON_SURFACE)
                palette.text(views, R.id.row_room, ColorRole.ON_SURFACE_VARIANT)
            }
            RowStatus.UPCOMING -> {
                palette.text(views, R.id.row_start, ColorRole.ON_SURFACE)
                palette.text(views, R.id.row_end, ColorRole.ON_SURFACE_VARIANT)
                palette.text(views, R.id.row_title, ColorRole.ON_SURFACE)
                palette.text(views, R.id.row_room, ColorRole.ON_SURFACE_VARIANT)
            }
        }
        return views
    }

    /** How many rows fit at the widget's current height, capped at [MAX_ROWS]. */
    private fun rowCapacity(context: Context, model: TodayModel, payload: WidgetPayload?, options: Bundle?): Int {
        val height = widgetHeightDp(options)
        if (height <= 0) return MAX_ROWS.coerceAtMost(model.rows.size)
        val res = context.resources
        val density = res.displayMetrics.density
        fun dp(id: Int) = res.getDimension(id) / density

        var available = height - 2 * dp(R.dimen.widget_padding) - dp(R.dimen.widget_today_header_height)
        if (!payload?.timetable.isNullOrBlank()) available -= dp(R.dimen.widget_today_line_height)
        if (model.banner != null) available -= dp(R.dimen.widget_today_line_height)
        if (model.stale) available -= dp(R.dimen.widget_today_line_height)

        val rowHeight = dp(R.dimen.widget_today_row_height)
        var fits = (available / rowHeight).toInt()
        if (fits < model.rows.size) {
            fits = ((available - dp(R.dimen.widget_today_line_height)) / rowHeight).toInt()
        }
        return fits.coerceIn(1, MAX_ROWS)
    }

    /**
     * Picks which rows to show when not all of them fit: starts at the first class that hasn't
     * ended and backfills with earlier ones if there's room left at the end of the day.
     */
    private fun visibleWindow(model: TodayModel, capacity: Int): List<TodayRow> {
        val rows = model.rows
        if (rows.size <= capacity) return rows
        val firstRelevant = rows.indexOfFirst { it.status != RowStatus.PAST }.let { if (it < 0) rows.size else it }
        val start = firstRelevant.coerceAtMost(rows.size - capacity)
        return rows.subList(start, start + capacity)
    }

    private companion object {
        const val MAX_ROWS = 6
        const val PAST_BAR_ALPHA = 90
        const val OPAQUE = 0xFF000000.toInt()
        val TEXT_IDS = intArrayOf(R.id.row_start, R.id.row_end, R.id.row_title, R.id.row_room)
    }
}
