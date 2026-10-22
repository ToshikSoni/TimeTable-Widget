import 'formatting.dart';
import 'models.dart';
import 'schedule.dart';

enum ReminderKind { classSoon, classStart, alarm, summary, task }

/// A notification the app intends to show at [at].
class PlannedReminder {
  PlannedReminder({
    required this.key,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    this.payload,
  });

  /// Stable identity, so re-planning yields the same notification ids.
  final String key;
  final ReminderKind kind;
  final DateTime at;
  final String title;
  final String body;
  final String? payload;

  /// 31-bit id derived from [key] (FNV-1a), stable across runs.
  int get id {
    var h = 0x811c9dc5;
    for (final c in key.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h & 0x7FFFFFFF;
  }

  @override
  String toString() => '$kind @ $at: $title';
}

class ReminderPlanner {
  const ReminderPlanner._();

  /// Plans every reminder due in `[from, from + horizon)`.
  static List<PlannedReminder> plan(
    AppData data, {
    required DateTime from,
    Duration horizon = const Duration(days: 7),
    bool use24h = true,
  }) {
    final s = data.settings;
    final tt = data.active;
    final until = from.add(horizon);
    final fmt = TimeFormat(use24h);
    final out = <PlannedReminder>[];

    void add(PlannedReminder r) {
      if (!r.at.isBefore(from) && r.at.isBefore(until)) out.add(r);
    }

    if (tt != null) {
      var day = dateOnly(from);
      final lastDay = dateOnly(until);
      while (!day.isAfter(lastDay)) {
        final plan = ScheduleEngine.dayPlan(tt, day);
        final classes = plan.active;

        if (s.remindersEnabled) {
          for (final o in classes) {
            final lead = o.subject?.reminderMinutes ?? s.reminderMinutes;
            if (lead < 0) continue;
            final where = [
              if (o.room != null) o.room!,
              if (o.teacher != null) o.teacher!.displayName,
            ].join(' · ');
            final codePrefix = o.code.isNotEmpty ? '${o.code} · ' : '';
            add(
              PlannedReminder(
                key: 'class|${o.key}',
                kind: ReminderKind.classSoon,
                at: o.start.subtract(Duration(minutes: lead)),
                title: lead == 0
                    ? '${o.title} is starting'
                    : '${o.title} in ${humanDuration(Duration(minutes: lead))}',
                body:
                    '$codePrefix${fmt.rangeOf(o.start, o.end)}'
                    '${where.isEmpty ? '' : ' · $where'}',
                payload: 'class:${o.key}',
              ),
            );
            if (s.notifyAtStart && lead > 0) {
              add(
                PlannedReminder(
                  key: 'start|${o.key}',
                  kind: ReminderKind.classStart,
                  at: o.start,
                  title: '${o.title} is starting',
                  body: where.isEmpty ? fmt.rangeOf(o.start, o.end) : where,
                  payload: 'class:${o.key}',
                ),
              );
            }
          }
        }

        if (classes.isNotEmpty) {
          final first = classes.first;
          if (s.morningAlarm) {
            add(
              PlannedReminder(
                key: 'alarm|${dateKey(day)}',
                kind: ReminderKind.alarm,
                at: first.start.subtract(Duration(minutes: s.morningAlarmLead)),
                title: 'Time to get going',
                body:
                    'First class: ${first.title} at ${fmt.time(first.start)}'
                    '${first.room != null ? ' in ${first.room}' : ''}',
                payload: 'alarm:${dateKey(day)}',
              ),
            );
          }
          if (s.dailySummary) {
            final at = day.add(Duration(minutes: s.dailySummaryAt));
            if (at.isBefore(first.start)) {
              final n = classes.length;
              final banner = plan.followsOtherDay
                  ? ' (${weekdayName(plan.effectiveWeekday!)} timetable)'
                  : '';
              add(
                PlannedReminder(
                  key: 'summary|${dateKey(day)}',
                  kind: ReminderKind.summary,
                  at: at,
                  title: '$n ${n == 1 ? 'class' : 'classes'} today$banner',
                  body:
                      '${fmt.time(first.start)} – ${fmt.time(plan.lastEnd!)}'
                      ' · first up: ${first.shortTitle}'
                      '${first.room != null ? ' in ${first.room}' : ''}',
                  payload: 'today',
                ),
              );
            }
          }
        }
        day = DateTime(day.year, day.month, day.day + 1);
      }
    }

    if (s.taskReminders) {
      for (final task in data.tasks) {
        if (task.done || task.due == null || task.remindBefore < 0) continue;
        final subject = tt?.subject(task.subjectId);
        add(
          PlannedReminder(
            key: 'task|${task.id}|${task.due!.millisecondsSinceEpoch}',
            kind: ReminderKind.task,
            at: task.due!.subtract(Duration(minutes: task.remindBefore)),
            title:
                '${task.type.label} due ${relativeDay(task.due!, task.due!.subtract(Duration(minutes: task.remindBefore))).toLowerCase()}',
            body: [task.title, if (subject != null) subject.label, fmt.time(task.due!)].join(' · '),
            payload: 'task:${task.id}',
          ),
        );
      }
    }

    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }
}
