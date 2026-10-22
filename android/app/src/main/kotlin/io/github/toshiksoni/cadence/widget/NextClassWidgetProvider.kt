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

/** Shows the class in progress (with a progress bar) or the next one coming up. */
class NextClassWidgetProvider : HomeWidgetProvider() {

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
        val model = WidgetState.nextClass(payload, now, zone)
        val format = WidgetFormatter(context, payload?.use24h ?: true, zone)
        val palette = WidgetPalette(
            context,
            payload?.theme ?: WidgetTheme.SYSTEM,
            payload?.accent ?: WidgetPayload.DEFAULT_ACCENT,
        )
        val heightDp = widgetHeightDp(options)
        val compact = heightDp in 1 until COMPACT_HEIGHT_DP

        val views = RemoteViews(context.packageName, R.layout.widget_next_class)
        views.setOnClickPendingIntent(android.R.id.background, launchAppIntent(context))
        palette.color(views, R.id.widget_surface, "setColorFilter", ColorRole.SURFACE)
        palette.accentText(views, R.id.next_label)
        palette.text(views, R.id.next_relative, ColorRole.ON_SURFACE_VARIANT)
        palette.text(views, R.id.next_title, ColorRole.ON_SURFACE)
        palette.text(views, R.id.next_subtitle, ColorRole.ON_SURFACE_VARIANT)
        palette.text(views, R.id.next_time, ColorRole.ON_SURFACE)
        palette.accentText(views, R.id.next_banner)
        palette.text(views, R.id.next_hint, ColorRole.ON_SURFACE_DIM)
        palette.progress(views, R.id.next_progress)

        if (compact) {
            val padding = context.resources.getDimensionPixelSize(R.dimen.widget_padding_compact)
            views.setViewPadding(R.id.next_content, padding, padding, padding, padding)
        }
        views.setInt(R.id.next_title, "setMaxLines", if (compact) 1 else 2)
        views.setTextOrGone(R.id.next_banner, model.banner.takeUnless { compact })
        views.setViewVisibility(R.id.next_hint, if (model.stale && !compact) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.next_progress, View.GONE)

        when (val state = model.state) {
            is NextClassState.Ongoing -> {
                val event = state.event
                views.setTextOrGone(R.id.next_label, context.getString(R.string.widget_now))
                views.setTextOrGone(
                    R.id.next_relative,
                    context.getString(R.string.widget_left, format.duration(state.minutesLeft)),
                )
                showEvent(views, event, format.location(event), compact)
                views.setTextOrGone(
                    R.id.next_time,
                    context.getString(R.string.widget_until, format.time(event.end)).takeUnless { compact },
                )
                views.setProgressBar(R.id.next_progress, PROGRESS_MAX, (state.progress * PROGRESS_MAX).toInt(), false)
                views.setViewVisibility(R.id.next_progress, View.VISIBLE)
            }
            is NextClassState.Upcoming -> {
                val event = state.event
                views.setTextOrGone(R.id.next_label, context.getString(R.string.widget_next))
                views.setTextOrGone(R.id.next_relative, format.startsIn(state.minutesUntil))
                showEvent(views, event, format.location(event), compact)
                views.setTextOrGone(
                    R.id.next_time,
                    context.getString(R.string.widget_at, format.time(event.start)).takeUnless { compact },
                )
            }
            is NextClassState.DoneForToday -> {
                views.setTextOrGone(R.id.next_label, null)
                views.setTextOrGone(R.id.next_relative, null)
                views.setViewVisibility(R.id.next_color_bar, View.GONE)
                views.setTextViewText(
                    R.id.next_title,
                    context.getString(
                        if (state.hadClassesToday) R.string.widget_done_for_today else R.string.widget_no_classes_today
                    ),
                )
                views.setTextOrGone(R.id.next_subtitle, state.next?.let { format.nextDayLine(it, model.today) })
                views.setTextOrGone(R.id.next_time, null)
            }
            NextClassState.Empty -> {
                views.setTextOrGone(R.id.next_label, null)
                views.setTextOrGone(R.id.next_relative, null)
                views.setViewVisibility(R.id.next_color_bar, View.GONE)
                views.setTextViewText(R.id.next_title, context.getString(R.string.widget_no_classes))
                views.setTextOrGone(R.id.next_subtitle, context.getString(R.string.widget_tap_to_open))
                views.setTextOrGone(R.id.next_time, null)
            }
        }
        return views
    }

    private fun showEvent(views: RemoteViews, event: WidgetEvent, location: String, compact: Boolean) {
        views.setViewVisibility(R.id.next_color_bar, View.VISIBLE)
        views.setInt(R.id.next_color_bar, "setColorFilter", event.color or OPAQUE)
        views.setTextViewText(R.id.next_title, event.title)
        views.setTextOrGone(R.id.next_subtitle, location.takeUnless { compact })
    }

    private companion object {
        const val PROGRESS_MAX = 1000
        const val COMPACT_HEIGHT_DP = 100
        const val OPAQUE = 0xFF000000.toInt()
    }
}

internal fun RemoteViews.setTextOrGone(id: Int, text: CharSequence?) {
    if (text.isNullOrBlank()) {
        setViewVisibility(id, View.GONE)
    } else {
        setTextViewText(id, text)
        setViewVisibility(id, View.VISIBLE)
    }
}
