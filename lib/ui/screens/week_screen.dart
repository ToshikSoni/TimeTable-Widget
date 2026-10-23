import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../../core/formatting.dart';
import '../../core/models.dart';
import '../../core/schedule.dart';
import '../app_scope.dart';
import '../editors/entry_editor.dart';
import '../editors/misc_editors.dart';
import '../theme.dart';
import '../widgets/class_tile.dart';
import '../widgets/common.dart';
import 'no_timetable.dart';
import 'settings/data_actions.dart';

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  DateTime? _monday;
  bool _list = false;
  final _gridKey = GlobalKey();
  final _scroll = ScrollController();
  bool _scrolledToNow = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Long days (routines span 24 hours) open at the current time.
  void _scrollToNow(Timetable tt, List<DateTime> days, DateTime now) {
    if (_scrolledToNow) return;
    _scrolledToNow = true;
    final (first, _) = WeekGrid.range(tt, [for (final d in days) ScheduleEngine.dayPlan(tt, d)]);
    final offset = (now.hour * 60 + now.minute - first - 90) * WeekGrid.ppm;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients || offset <= 0) return;
      _scroll.jumpTo(offset.clamp(0, _scroll.position.maxScrollExtent));
    });
  }

  DateTime _mondayOf(DateTime d) => dateOnly(d).subtract(Duration(days: d.weekday - 1));

  @override
  Widget build(BuildContext context) {
    final tt = context.store.timetable;
    final now = ClockScope.now(context);
    if (tt == null) return const NoTimetable();
    final monday = _monday ?? _mondayOf(now);
    final days = _visibleDays(context, tt, monday);
    final thisWeek = monday == _mondayOf(now);
    if (thisWeek && !_list) _scrollToNow(tt, days, now);
    final sunday = monday.add(const Duration(days: 6));
    final rangeLabel = monday.month == sunday.month
        ? '${monday.day} – ${DateFormat('d MMMM').format(sunday)}'
        : '${DateFormat('d MMM').format(monday)} – ${DateFormat('d MMM').format(sunday)}';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(thisWeek ? 'This week' : 'Week', style: context.text.titleLarge),
            Text(
              rangeLabel,
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Previous week',
            onPressed: () => setState(() => _monday = monday.subtract(const Duration(days: 7))),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          if (!thisWeek)
            IconButton(
              tooltip: 'This week',
              onPressed: () => setState(() => _monday = null),
              icon: const Icon(Icons.today_rounded),
            ),
          IconButton(
            tooltip: 'Next week',
            onPressed: () => setState(() => _monday = monday.add(const Duration(days: 7))),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          IconButton(
            tooltip: _list ? 'Grid view' : 'List view',
            onPressed: () => setState(() => _list = !_list),
            icon: Icon(_list ? Icons.grid_view_rounded : Icons.view_agenda_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) async {
              switch (v) {
                case 'image':
                  if (_list) setState(() => _list = false);
                  await WidgetsBinding.instance.endOfFrame;
                  if (!context.mounted) return;
                  final boundary =
                      _gridKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                  if (boundary != null) await DataActions.exportImage(context, boundary);
                case 'ics':
                  await DataActions.exportIcs(context);
                case 'share':
                  await DataActions.shareTimetable(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'image',
                child: ListTile(leading: Icon(Icons.image_outlined), title: Text('Save as image')),
              ),
              PopupMenuItem(
                value: 'ics',
                child: ListTile(
                  leading: Icon(Icons.event_note_outlined),
                  title: Text('Export to calendar (.ics)'),
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.ios_share_rounded),
                  title: Text('Share timetable file'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showEditor(context, const EntryEditor()),
        icon: const Icon(Icons.add_rounded),
        label: Text(tt.kind.itemTitle),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _list
            ? _WeekList(key: const ValueKey('list'), timetable: tt, days: days, now: now)
            : SingleChildScrollView(
                key: const ValueKey('grid'),
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(8, 0, 12, 110),
                child: RepaintBoundary(
                  key: _gridKey,
                  child: ColoredBox(
                    color: context.colors.surface,
                    child: WeekGrid(timetable: tt, days: days, now: now),
                  ),
                ),
              ),
      ),
    );
  }

  List<DateTime> _visibleDays(BuildContext context, Timetable tt, DateTime monday) {
    final showWeekends = context.settings.showWeekends;
    return [
      for (var i = 0; i < 7; i++)
        if (_shows(tt, monday.add(Duration(days: i)), showWeekends)) monday.add(Duration(days: i)),
    ];
  }

  bool _shows(Timetable tt, DateTime day, bool showWeekends) {
    if (tt.workingDays.contains(day.weekday)) return true;
    if (showWeekends) return true;
    // Weekend days appear when something is actually on.
    final plan = ScheduleEngine.dayPlan(tt, day);
    return plan.occurrences.isNotEmpty || plan.special != null && !plan.isHoliday;
  }
}

/// A calendar-style week grid with a continuous time axis.
class WeekGrid extends StatelessWidget {
  const WeekGrid({super.key, required this.timetable, required this.days, required this.now});

  final Timetable timetable;
  final List<DateTime> days;
  final DateTime now;

  static const ppm = 1.15; // pixels per minute
  static const _ppm = ppm;
  static const headerHeight = 58.0;
  static const _headerHeight = headerHeight;

  /// The visible time range in minutes, rounded out to whole hours.
  static (int, int) range(Timetable timetable, List<DayPlan> plans) {
    var first = 24 * 60, last = 0;
    for (final p in plans) {
      for (final o in p.occurrences) {
        first = math.min(first, o.entry.start);
        last = math.max(last, math.min(o.entry.end, 24 * 60));
      }
      if (p.carryOver.isNotEmpty) first = 0;
    }
    for (final p in timetable.periods) {
      first = math.min(first, p.start);
      last = math.max(last, p.end);
    }
    if (first >= last) {
      first = 8 * 60;
      last = 17 * 60;
    }
    return ((first ~/ 60) * 60, math.min(24 * 60, ((last + 59) ~/ 60) * 60));
  }

  @override
  Widget build(BuildContext context) {
    final plans = [for (final d in days) ScheduleEngine.dayPlan(timetable, d)];
    final (first, last) = range(timetable, plans);
    final height = (last - first) * _ppm;
    final fmt = context.timeFormat;
    final axisWidth = context.use24h ? 44.0 : 54.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final colWidth = (constraints.maxWidth - axisWidth) / math.max(1, days.length);
        return SizedBox(
          height: height + _headerHeight + 8,
          child: Stack(
            children: [
              // Hour lines and labels.
              for (var m = first; m <= last; m += 60)
                Positioned(
                  top: _headerHeight + (m - first) * _ppm,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      SizedBox(
                        width: axisWidth,
                        child: Transform.translate(
                          offset: const Offset(0, -7),
                          child: Text(
                            fmt.minutes(m),
                            style: context.text.labelSmall?.copyWith(
                              color: context.colors.outline,
                              fontFeatures: tabular,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: context.colors.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              // Breaks such as lunch, across all days.
              for (final b in timetable.periods.where((p) => p.isBreak))
                Positioned(
                  top: _headerHeight + (b.start - first) * _ppm,
                  height: (b.end - b.start) * _ppm,
                  left: axisWidth,
                  right: 0,
                  child: _BreakBand(label: b.label),
                ),
              for (var i = 0; i < days.length; i++) ...[
                Positioned(
                  left: axisWidth + i * colWidth,
                  width: colWidth,
                  top: 0,
                  height: _headerHeight,
                  child: _DayHeader(plan: plans[i], today: days[i] == dateOnly(now)),
                ),
                Positioned(
                  left: axisWidth + i * colWidth,
                  width: colWidth,
                  top: _headerHeight,
                  height: height,
                  child: _DayColumn(
                    plan: plans[i],
                    first: first,
                    ppm: _ppm,
                    now: now,
                    width: colWidth,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BreakBand extends StatelessWidget {
  const _BreakBand({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 2),
    decoration: BoxDecoration(
      color: context.colors.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(10),
    ),
    alignment: Alignment.center,
    child: Text(
      label.toUpperCase(),
      style: context.text.labelSmall?.copyWith(
        color: context.colors.outline,
        letterSpacing: 6,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.plan, required this.today});
  final DayPlan plan;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = plan.date;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          DateFormat('EEE').format(d).toUpperCase(),
          style: context.text.labelSmall?.copyWith(
            color: today ? c.primary : c.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 30,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: today ? c.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '${d.day}',
            style: context.text.titleSmall?.copyWith(
              color: today ? c.onPrimary : c.onSurface,
              fontFeatures: tabular,
            ),
          ),
        ),
        if (plan.followsOtherDay || plan.isHoliday)
          Tooltip(
            message: plan.isHoliday ? 'Holiday' : 'Follows ${weekdayName(plan.effectiveWeekday!)}',
            child: Icon(
              plan.isHoliday ? Icons.beach_access_outlined : Icons.swap_horiz_rounded,
              size: 12,
              color: c.tertiary,
            ),
          ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.plan,
    required this.first,
    required this.ppm,
    required this.now,
    required this.width,
  });
  final DayPlan plan;
  final int first;
  final double ppm;
  final DateTime now;
  final double width;

  @override
  Widget build(BuildContext context) {
    // Overnight entries are cut at midnight and continue at the top of the
    // next day's column.
    const day = 24 * 60;
    final segments = <({Occurrence o, int start, int end})>[
      for (final o in plan.carryOver) (o: o, start: 0, end: o.entry.end - day),
      for (final o in plan.occurrences)
        (o: o, start: o.entry.start, end: math.min(o.entry.end, day)),
    ];
    final lanes = ScheduleEngine.layoutSegments(segments, (s) => s.start, (s) => s.end);
    final isToday = plan.date == dateOnly(now);
    final nowMinutes = now.hour * 60 + now.minute;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (d) {
        final minutes = first + (d.localPosition.dy / ppm).round();
        final snapped = (minutes ~/ 15) * 15;
        showEditor(
          context,
          EntryEditor(weekday: plan.effectiveWeekday ?? plan.date.weekday, start: snapped),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isToday)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          if (plan.isHoliday)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: context.colors.tertiaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    (plan.special?.label ?? 'Holiday').toUpperCase(),
                    style: context.text.labelMedium?.copyWith(
                      color: context.colors.onTertiaryContainer,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
            ),
          for (final seg in segments)
            Positioned(
              top: (seg.start - first) * ppm + 1.5,
              height: math.max(18, (seg.end - seg.start) * ppm - 3),
              left: 2 + lanes[seg]!.lane * (width - 4) / lanes[seg]!.lanes,
              width: (width - 4) / lanes[seg]!.lanes - (lanes[seg]!.lanes > 1 ? 2 : 0),
              child: _Block(occurrence: seg.o, now: now),
            ),
          if (isToday && nowMinutes >= first)
            Positioned(
              top: (nowMinutes - first) * ppm - 4,
              left: -4,
              right: 0,
              child: IgnorePointer(
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: context.colors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(child: Container(height: 2, color: context.colors.error)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.occurrence, required this.now});
  final Occurrence occurrence;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final o = occurrence;
    final tone = context.tone(o.color);
    final live = o.isLiveAt(now);
    return Opacity(
      opacity: o.cancelled ? 0.45 : 1,
      child: Material(
        color: tone.container,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: live ? tone.accent : tone.accent.withValues(alpha: 0.25),
            width: live ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showClassDetails(context, o),
          child: LayoutBuilder(
            builder: (context, c) {
              final roomy = c.maxWidth > 92;
              final tall = c.maxHeight > 56;
              // Parallel electives in a phone-width column: colour only.
              if (c.maxWidth < 30) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(width: 3, color: tone.accent),
                );
              }
              return Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 3, color: tone.accent),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(7, 5, 4, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (roomy || o.code.isEmpty)
                          Text(
                            o.shortTitle,
                            maxLines: tall ? 3 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: _titleStyle(tone, o, roomy ? 12.5 : 10.5),
                          )
                        else
                          // Narrow phone columns: shrink the code to fit rather than clip it.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(o.code, maxLines: 1, style: _titleStyle(tone, o, 11)),
                          ),
                        if (tall && o.room != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              [o.room!, if (o.entry.group != null) o.entry.group!].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: tone.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

TextStyle _titleStyle(SubjectTone tone, Occurrence o, double size) => TextStyle(
  fontSize: size,
  height: 1.2,
  fontWeight: FontWeight.w700,
  color: tone.onContainer,
  decoration: o.cancelled ? TextDecoration.lineThrough : null,
);

class _WeekList extends StatelessWidget {
  const _WeekList({super.key, required this.timetable, required this.days, required this.now});
  final Timetable timetable;
  final List<DateTime> days;
  final DateTime now;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
    children: [
      for (final d in days) ...[
        PageBody(
          child: SectionHeader(
            DateFormat('EEEE, d MMM').format(d),
            trailing: d == dateOnly(now) ? Tag('TODAY', color: context.colors.primary) : null,
          ),
        ),
        ...() {
          final plan = ScheduleEngine.dayPlan(timetable, d);
          if (plan.occurrences.isEmpty) {
            return [
              PageBody(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        plan.isHoliday
                            ? 'Holiday${plan.special?.label != null ? ' · ${plan.special!.label}' : ''}'
                            : 'Nothing scheduled',
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            showEditor(context, SpecialDayEditor(date: d, day: plan.special)),
                        child: Text(plan.special == null ? 'Mark day' : 'Edit'),
                      ),
                    ],
                  ),
                ),
              ),
            ];
          }
          return [
            for (final o in plan.occurrences)
              PageBody(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ClassTile(occurrence: o, now: now),
                ),
              ),
          ];
        }(),
      ],
    ],
  );
}
