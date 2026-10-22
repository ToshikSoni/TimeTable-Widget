package io.github.toshiksoni.cadence.widget

import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.concurrent.TimeUnit

enum class WidgetTheme { SYSTEM, LIGHT, DARK }

enum class EventKind { LECTURE, LAB, TUTORIAL, ACTIVITY, EXAM, OTHER }

data class WidgetEvent(
    val start: Long,
    val end: Long,
    val title: String,
    val code: String,
    val room: String,
    val teacher: String,
    val kind: EventKind,
    val color: Int,
    val note: String,
) {
    fun isOngoing(now: Long) = now in start until end
}

/** Snapshot written by the Flutter side under [KEY]. */
data class WidgetPayload(
    val generatedAt: Long,
    val timetable: String,
    val use24h: Boolean,
    val theme: WidgetTheme,
    val accent: Int,
    val events: List<WidgetEvent>,
    val banners: Map<LocalDate, String>,
) {
    companion object {
        const val KEY = "cadence_payload"
        const val DEFAULT_ACCENT = 0xFF4F5BD5.toInt()

        fun parse(json: String?): WidgetPayload? {
            if (json.isNullOrBlank()) return null
            return try {
                val root = JSONObject(json)
                val events = buildList {
                    val array = root.optJSONArray("events")
                    for (i in 0 until (array?.length() ?: 0)) {
                        val e = array!!.optJSONObject(i) ?: continue
                        val start = e.optLong("s", -1L)
                        val end = e.optLong("e", -1L)
                        if (start < 0 || end < start) continue
                        add(
                            WidgetEvent(
                                start = start,
                                end = end,
                                title = e.text("t"),
                                code = e.text("c"),
                                room = e.text("r"),
                                teacher = e.text("p"),
                                kind = parseKind(e.text("k")),
                                // Dart may hand over the colour as an unsigned 32-bit value.
                                color = e.optLong("col", DEFAULT_ACCENT.toLong()).toInt(),
                                note = e.text("n"),
                            )
                        )
                    }
                }.sortedBy { it.start }

                val banners = buildMap {
                    val array = root.optJSONArray("days")
                    for (i in 0 until (array?.length() ?: 0)) {
                        val d = array!!.optJSONObject(i) ?: continue
                        val label = d.text("label")
                        val date = runCatching { LocalDate.parse(d.text("d")) }.getOrNull()
                        if (date != null && label.isNotBlank()) put(date, label)
                    }
                }

                WidgetPayload(
                    generatedAt = root.optLong("generatedAt", 0L),
                    timetable = root.text("timetable"),
                    use24h = root.optBoolean("use24h", true),
                    theme = when (root.optString("theme")) {
                        "light" -> WidgetTheme.LIGHT
                        "dark" -> WidgetTheme.DARK
                        else -> WidgetTheme.SYSTEM
                    },
                    accent = root.optLong("accent", DEFAULT_ACCENT.toLong()).toInt(),
                    events = events,
                    banners = banners,
                )
            } catch (_: Exception) {
                null
            }
        }

        /** Like optString, but a JSON null becomes "" instead of the string "null". */
        private fun JSONObject.text(key: String): String = if (isNull(key)) "" else optString(key)

        private fun parseKind(raw: String) = when (raw) {
            "lecture" -> EventKind.LECTURE
            "lab" -> EventKind.LAB
            "tutorial" -> EventKind.TUTORIAL
            "activity" -> EventKind.ACTIVITY
            "exam" -> EventKind.EXAM
            else -> EventKind.OTHER
        }
    }
}

sealed interface NextClassState {
    data class Ongoing(val event: WidgetEvent, val progress: Float, val minutesLeft: Long) : NextClassState
    data class Upcoming(val event: WidgetEvent, val minutesUntil: Long) : NextClassState

    /** Nothing left today; [next] is the first class on a later day, if any. */
    data class DoneForToday(val hadClassesToday: Boolean, val next: WidgetEvent?) : NextClassState
    data object Empty : NextClassState
}

enum class RowStatus { PAST, CURRENT, UPCOMING }

data class TodayRow(val event: WidgetEvent, val status: RowStatus)

data class NextClassModel(
    val state: NextClassState,
    val today: LocalDate,
    val banner: String?,
    val stale: Boolean,
)

data class TodayModel(
    val today: LocalDate,
    val rows: List<TodayRow>,
    val remaining: Int,
    val banner: String?,
    /** First class after today, used for the empty state. */
    val nextDay: WidgetEvent?,
    val stale: Boolean,
)

/** Pure selection logic; everything is derived from [now] and [zone]. */
object WidgetState {
    private val STALE_AFTER_MS = TimeUnit.DAYS.toMillis(7)

    fun nextClass(payload: WidgetPayload?, now: Long, zone: ZoneId): NextClassModel {
        val today = localDate(now, zone)
        if (payload == null) return NextClassModel(NextClassState.Empty, today, null, stale = false)

        val events = payload.events
        val todayEvents = eventsOn(events, today, zone)
        val ongoing = events.firstOrNull { it.isOngoing(now) }

        val state = when {
            ongoing != null -> {
                val total = (ongoing.end - ongoing.start).coerceAtLeast(1L)
                NextClassState.Ongoing(
                    event = ongoing,
                    progress = ((now - ongoing.start).toFloat() / total).coerceIn(0f, 1f),
                    minutesLeft = ceilMinutes(ongoing.end - now),
                )
            }
            else -> {
                val nextToday = todayEvents.firstOrNull { it.start > now }
                if (nextToday != null) {
                    NextClassState.Upcoming(nextToday, ceilMinutes(nextToday.start - now))
                } else {
                    val later = events.firstOrNull { it.start > now && localDate(it.start, zone) > today }
                    if (later == null && todayEvents.isEmpty() && events.none { it.end > now }) {
                        NextClassState.Empty
                    } else {
                        NextClassState.DoneForToday(todayEvents.isNotEmpty(), later)
                    }
                }
            }
        }
        return NextClassModel(state, today, payload.banners[today], isStale(payload, now))
    }

    fun today(payload: WidgetPayload?, now: Long, zone: ZoneId): TodayModel {
        val today = localDate(now, zone)
        if (payload == null) return TodayModel(today, emptyList(), 0, null, null, stale = false)

        val rows = eventsOn(payload.events, today, zone).map {
            val status = when {
                it.end <= now -> RowStatus.PAST
                it.start <= now -> RowStatus.CURRENT
                else -> RowStatus.UPCOMING
            }
            TodayRow(it, status)
        }
        val nextDay = payload.events.firstOrNull { localDate(it.start, zone) > today }
        return TodayModel(
            today = today,
            rows = rows,
            remaining = rows.count { it.status != RowStatus.PAST },
            banner = payload.banners[today],
            nextDay = nextDay,
            stale = isStale(payload, now),
        )
    }

    fun isStale(payload: WidgetPayload, now: Long): Boolean {
        if (now - payload.generatedAt > STALE_AFTER_MS) return true
        val lastEnd = payload.events.maxOfOrNull { it.end } ?: return false
        return lastEnd < now
    }

    /** Events that overlap the given local day, so a class running past midnight still shows up. */
    private fun eventsOn(events: List<WidgetEvent>, day: LocalDate, zone: ZoneId): List<WidgetEvent> {
        val dayStart = day.atStartOfDay(zone).toInstant().toEpochMilli()
        val dayEnd = day.plusDays(1).atStartOfDay(zone).toInstant().toEpochMilli()
        return events.filter { it.start < dayEnd && (it.end > dayStart || it.start >= dayStart) }
    }

    fun localDate(epochMs: Long, zone: ZoneId): LocalDate =
        Instant.ofEpochMilli(epochMs).atZone(zone).toLocalDate()

    private fun ceilMinutes(ms: Long): Long = (ms + 59_999L) / 60_000L
}
