import 'dart:convert';

import 'models.dart';
import 'palette.dart';

/// Reads `.tta` backups exported by the "TimeTable" Android app.
///
/// The file is a series of JSON objects separated by lines of `=`. Each
/// "week" in that app (a named set of activities) becomes one Cadence
/// routine timetable.
class TtaImporter {
  const TtaImporter._();

  static bool looksLikeTta(String raw) =>
      raw.trimLeft().startsWith('=') && raw.contains('"activities"');

  static List<Timetable> parse(String raw) {
    final sections = <String, dynamic>{};
    for (final chunk in raw.split(RegExp(r'^=+\s*$', multiLine: true))) {
      final text = chunk.trim();
      if (text.isEmpty) continue;
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) sections.addAll(decoded);
    }
    final activities = (sections['activities'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .where((a) => a['isDeleting'] != true)
        .toList();
    if (activities.isEmpty) throw const FormatException('No activities in this file');

    final weeks =
        (sections['weeks'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList()
          ..sort((a, b) => ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0));
    final links = (sections['activities_to_weeks'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => (week: m['id_week'], activity: m['id_activity']))
        .toList();

    Timetable build(String name, Iterable<Map<String, dynamic>> items) {
      final entries = <ClassEntry>[for (final a in items) ..._entries(a)];
      final days = {for (final e in entries) e.weekday}.toList()..sort();
      return Timetable(
        name: name,
        kind: TimetableKind.routine,
        workingDays: days.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : days,
        entries: entries,
      );
    }

    final byId = {for (final a in activities) a['activityId']: a};
    final result = <Timetable>[];
    final used = <Object?>{};
    for (final w in weeks) {
      final ids = links.where((l) => l.week == w['weekId']).map((l) => l.activity).toSet();
      final items = ids.map((id) => byId[id]).whereType<Map<String, dynamic>>().toList();
      if (items.isEmpty) continue;
      used.addAll(ids);
      final label = (w['label'] as String?)?.trim();
      result.add(
        build(label == null || label.isEmpty ? 'Week ${result.length + 1}' : label, items),
      );
    }
    final orphans = activities.where((a) => !used.contains(a['activityId'])).toList();
    if (orphans.isNotEmpty) {
      result.add(build(result.isEmpty ? 'Imported routine' : 'Other activities', orphans));
    }
    // The busiest week is usually the one in daily use; show it first.
    result.sort((a, b) => b.entries.length.compareTo(a.entries.length));
    return result;
  }

  static List<ClassEntry> _entries(Map<String, dynamic> a) {
    final start =
        ((a['startHour'] as num?) ?? 0).toInt() * 60 + ((a['startMinute'] as num?) ?? 0).toInt();
    final duration = ((a['durationInMinutes'] as num?) ?? 60).toInt().clamp(1, 24 * 60);
    final colorIndex = (a['colorIndex'] as num?)?.toInt() ?? -1;
    final label = (a['label'] as String?)?.trim();
    final room = (a['room'] as String?)?.trim();
    final active = a['reminderIsActive'] == true;
    final lead = ((a['reminderTimerInMinutes'] as num?) ?? 0).toInt();
    final days = '${a['strDaysOfWeek'] ?? ''}'
        .split('@')
        .map(int.tryParse)
        .whereType<int>()
        .where((d) => d >= 1 && d <= 7)
        // That app counts from Sunday = 1.
        .map((d) => d == 1 ? DateTime.sunday : d - 1)
        .toSet();
    return [
      for (final d in days)
        ClassEntry(
          weekday: d,
          start: start,
          end: start + duration,
          title: label == null || label.isEmpty ? 'Activity' : label,
          room: room == null || room.isEmpty ? null : room,
          kind: ClassKind.activity,
          color: colorIndex < 0 ? null : kRoutinePalette[colorIndex % kRoutinePalette.length],
          reminderMinutes: active ? lead : -1,
          alarm: active && a['reminderIsAlarm'] == true,
          doNotDisturb: a['doNotDisturb'] == true,
        ),
    ];
  }
}
