import 'package:flutter/material.dart';
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
import '../widgets/illustrations.dart';
import '../widgets/now_card.dart';
import 'no_timetable.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => TodayScreenState();
}

class TodayScreenState extends State<TodayScreen> {
  DateTime? _selected;

  void showDate(DateTime date) => setState(() => _selected = dateOnly(date));

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final tt = store.timetable;
    final now = ClockScope.now(context);
    if (tt == null) return const NoTimetable();
    final selected = _selected ?? dateOnly(now);
    final isToday = selected == dateOnly(now);
    final plan = ScheduleEngine.dayPlan(tt, selected);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageBody(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                  child: _Header(
                    date: selected,
                    now: now,
                    onPickDate: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: selected,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) showDate(d);
                    },
                    onToday: isToday ? null : () => showDate(now),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: PageBody(
                child: _WeekStrip(
                  timetable: tt,
                  selected: selected,
                  today: dateOnly(now),
                  onSelect: showDate,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              sliver: SliverToBoxAdapter(
                child: PageBody(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: _DayBody(
                      key: ValueKey(selected),
                      timetable: tt,
                      plan: plan,
                      now: now,
                      isToday: isToday,
                      onJump: showDate,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add',
        onPressed: () => _showAddMenu(context, selected),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showAddMenu(BuildContext context, DateTime date) => showModalBottomSheet(
    useRootNavigator: true,
    context: context,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AddOption(
              icon: Icons.repeat_rounded,
              title: 'Weekly class',
              subtitle: 'Repeats every ${weekdayName(date.weekday)}',
              onTap: () {
                Navigator.pop(sheet);
                showEditor(context, EntryEditor(weekday: date.weekday));
              },
            ),
            _AddOption(
              icon: Icons.event_available_outlined,
              title: 'Extra class',
              subtitle: 'Only on ${DateFormat('EEEE, d MMM').format(date)}',
              onTap: () {
                Navigator.pop(sheet);
                showEditor(context, EntryEditor(date: date));
              },
            ),
            _AddOption(
              icon: Icons.task_alt_rounded,
              title: 'Task or exam',
              subtitle: 'Assignment, test, reading…',
              onTap: () {
                Navigator.pop(sheet);
                showEditor(context, const TaskEditor());
              },
            ),
            _AddOption(
              icon: Icons.beach_access_outlined,
              title: 'Holiday or special day',
              subtitle: 'Day off, or follow another day’s timetable',
              onTap: () {
                Navigator.pop(sheet);
                showEditor(context, SpecialDayEditor(date: date));
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _AddOption extends StatelessWidget {
  const _AddOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(
      backgroundColor: context.colors.secondaryContainer,
      foregroundColor: context.colors.onSecondaryContainer,
      child: Icon(icon),
    ),
    title: Text(title, style: context.text.titleSmall),
    subtitle: Text(subtitle),
    onTap: onTap,
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.date, required this.now, required this.onPickDate, this.onToday});
  final DateTime date;
  final DateTime now;
  final VoidCallback onPickDate;
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) {
    final isToday = onToday == null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isToday ? greeting(now) : relativeDay(date, now),
                style: context.text.titleSmall?.copyWith(color: context.colors.primary),
              ),
              const SizedBox(height: 2),
              Text(DateFormat('EEEE, d MMMM').format(date), style: context.text.headlineSmall),
            ],
          ),
        ),
        if (onToday != null)
          TextButton.icon(
            onPressed: onToday,
            icon: const Icon(Icons.today_rounded, size: 18),
            label: const Text('Today'),
          ),
        IconButton(
          tooltip: 'Pick a date',
          onPressed: onPickDate,
          icon: const Icon(Icons.calendar_month_outlined),
        ),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.timetable,
    required this.selected,
    required this.today,
    required this.onSelect,
  });
  final Timetable timetable;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final monday = selected.subtract(Duration(days: selected.weekday - 1));
    final days = [for (var i = 0; i < 7; i++) DateTime(monday.year, monday.month, monday.day + i)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous week',
            visualDensity: VisualDensity.compact,
            onPressed: () => onSelect(selected.subtract(const Duration(days: 7))),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          for (final d in days)
            Expanded(
              child: _DayPill(
                date: d,
                selected: d == selected,
                today: d == today,
                count: ScheduleEngine.dayPlan(timetable, d).active.length,
                onTap: () => onSelect(d),
              ),
            ),
          IconButton(
            tooltip: 'Next week',
            visualDensity: VisualDensity.compact,
            onPressed: () => onSelect(selected.add(const Duration(days: 7))),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.date,
    required this.selected,
    required this.today,
    required this.count,
    required this.onTap,
  });
  final DateTime date;
  final bool selected;
  final bool today;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.onPrimary : (today ? c.primary : c.onSurface);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? c.primary
                : (today ? c.primaryContainer.withValues(alpha: 0.5) : Colors.transparent),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                DateFormat('E').format(date).substring(0, 1),
                style: context.text.labelSmall?.copyWith(
                  color: selected ? c.onPrimary.withValues(alpha: 0.8) : c.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${date.day}',
                style: context.text.titleMedium?.copyWith(color: fg, fontFeatures: tabular),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < count.clamp(0, 3); i++)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? c.onPrimary : c.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  if (count == 0) const SizedBox(height: 4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayBody extends StatelessWidget {
  const _DayBody({
    super.key,
    required this.timetable,
    required this.plan,
    required this.now,
    required this.isToday,
    required this.onJump,
  });

  final Timetable timetable;
  final DayPlan plan;
  final DateTime now;
  final bool isToday;
  final ValueChanged<DateTime> onJump;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    var i = 0;

    if (plan.special != null || plan.outOfRange) {
      children.add(
        Entrance(
          index: i++,
          child: _Banner(plan: plan),
        ),
      );
      children.add(const SizedBox(height: 12));
    }

    if (isToday) {
      children.add(
        Entrance(
          index: i++,
          child: NowCard(timetable: timetable, now: now),
        ),
      );
      children.add(const SizedBox(height: 8));
    }

    final occ = plan.occurrences;
    if (occ.isEmpty) {
      final next = ScheduleEngine.next(
        timetable,
        plan.date.add(const Duration(hours: 23, minutes: 59)),
      );
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: EmptyState(
            illustration: const Illustration(Art.freeDay),
            title: plan.isHoliday ? 'Holiday — enjoy it' : 'No classes',
            message: next == null
                ? 'Nothing else is scheduled yet.'
                : 'Next up: ${next.shortTitle}, ${relativeDay(next.start, plan.date).toLowerCase()} at ${context.timeFormat.time(next.start)}',
            action: next == null
                ? null
                : OutlinedButton.icon(
                    onPressed: () => onJump(next.date),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Show that day'),
                  ),
          ),
        ),
      );
    } else {
      final active = plan.active;
      final summary = active.isEmpty
          ? 'All classes cancelled'
          : '${active.length} ${active.length == 1 ? 'class' : 'classes'} · ${context.timeFormat.time(plan.firstStart!)} – ${context.timeFormat.time(plan.lastEnd!)}';
      children.add(
        SectionHeader(
          'Schedule',
          trailing: Text(
            summary,
            style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
      );
      children.addAll(_timeline(context, occ, i));
    }

    final tasks = context.store.data.tasks
        .where((t) => !t.done && t.due != null && dateOnly(t.due!) == plan.date)
        .toList();
    if (tasks.isNotEmpty) {
      children.add(const SectionHeader('Due this day'));
      for (final t in tasks) {
        final s = timetable.subject(t.subjectId);
        children.add(
          Card(
            child: ListTile(
              leading: Icon(
                t.type == TaskType.exam ? Icons.edit_note_rounded : Icons.assignment_outlined,
                color: s == null ? null : context.tone(s.color).accent,
              ),
              title: Text(t.title),
              subtitle: Text(
                [t.type.label, ?s?.label, context.timeFormat.time(t.due!)].join(' · '),
              ),
              trailing: Checkbox(
                value: t.done,
                onChanged: (v) => context.readStore.upsertTask(t.copyWith(done: v ?? false)),
              ),
              onTap: () => showEditor(context, TaskEditor(task: t)),
            ),
          ),
        );
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  List<Widget> _timeline(BuildContext context, List<Occurrence> occ, int startIndex) {
    final out = <Widget>[];
    var index = startIndex;
    final breaks = timetable.periods.where((p) => p.isBreak).toList();
    DateTime? lastEnd;
    for (final o in occ) {
      if (lastEnd != null && !o.cancelled && o.start.isAfter(lastEnd)) {
        final gap = o.start.difference(lastEnd);
        final gapStart = lastEnd.hour * 60 + lastEnd.minute;
        final brk = breaks.where((b) => b.start >= gapStart && b.end <= o.entry.start);
        if (brk.isNotEmpty) {
          out.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: GapTile(
                label: brk.first.label,
                duration: gap,
                icon: Icons.restaurant_outlined,
              ),
            ),
          );
        } else if (gap.inMinutes >= 20) {
          out.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: GapTile(label: 'Free', duration: gap),
            ),
          );
        }
      }
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Entrance(
            index: index++,
            child: ClassTile(occurrence: o, now: now),
          ),
        ),
      );
      if (!o.cancelled && (lastEnd == null || o.end.isAfter(lastEnd))) lastEnd = o.end;
    }
    return out;
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.plan});
  final DayPlan plan;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, title, subtitle) = plan.outOfRange
        ? (
            Icons.event_busy_outlined,
            'Outside this timetable’s dates',
            'Adjust the dates in Settings → Timetable if this is wrong.',
          )
        : plan.isHoliday
        ? (Icons.beach_access_outlined, 'Holiday', plan.special!.label ?? 'No classes today')
        : plan.followsOtherDay
        ? (
            Icons.swap_horiz_rounded,
            'Follows ${weekdayName(plan.effectiveWeekday!)}’s timetable',
            plan.special!.label ?? 'Special working day',
          )
        : (Icons.info_outline_rounded, plan.special!.label ?? 'Note', 'Special day');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.tertiaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: c.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall?.copyWith(color: c.onTertiaryContainer)),
                Text(
                  subtitle,
                  style: context.text.bodySmall?.copyWith(
                    color: c.onTertiaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
