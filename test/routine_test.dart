import 'package:cadence/core/models.dart';
import 'package:cadence/core/reminders.dart';
import 'package:cadence/core/sample_data.dart';
import 'package:cadence/core/schedule.dart';
import 'package:cadence/core/store.dart';
import 'package:cadence/core/tta_import.dart';
import 'package:cadence/services/dnd.dart';
import 'package:flutter_test/flutter_test.dart';

// A tiny, made-up export in the TimeTable app's .tta format.
const _tta = '''
========================
{"weeks":[{"weekId":1,"label":"Normal week","order":0,"colorIndex":-1},{"weekId":2,"label":"Holiday week","order":1,"colorIndex":-1}]}
========================
{"tags":[]}
========================
{"activities":[
{"activityId":1,"strDaysOfWeek":"2@3@4@5@6","label":"Office","room":"HQ","colorIndex":4,"startHour":9,"startMinute":0,"durationInMinutes":480,"reminderIsActive":true,"reminderTimerInMinutes":15,"reminderIsAlarm":false,"doNotDisturb":true,"isDeleting":false},
{"activityId":2,"strDaysOfWeek":"1@2@3@4@5@6@7","label":"Sleep","room":"","colorIndex":15,"startHour":23,"startMinute":0,"durationInMinutes":480,"reminderIsActive":false,"reminderTimerInMinutes":0,"reminderIsAlarm":false,"doNotDisturb":true,"isDeleting":false},
{"activityId":3,"strDaysOfWeek":"1","label":"Wake up","room":"","colorIndex":2,"startHour":7,"startMinute":0,"durationInMinutes":10,"reminderIsActive":true,"reminderTimerInMinutes":0,"reminderIsAlarm":true,"doNotDisturb":false,"isDeleting":false},
{"activityId":4,"strDaysOfWeek":"7","label":"Gone","room":"","colorIndex":0,"startHour":12,"startMinute":0,"durationInMinutes":60,"reminderIsActive":false,"reminderTimerInMinutes":0,"reminderIsAlarm":false,"doNotDisturb":false,"isDeleting":true},
{"activityId":5,"strDaysOfWeek":"7","label":"Hike","room":"","colorIndex":1,"startHour":8,"startMinute":0,"durationInMinutes":240,"reminderIsActive":false,"reminderTimerInMinutes":0,"reminderIsAlarm":false,"doNotDisturb":false,"isDeleting":false}
]}
========================
{"activities_to_weeks":[{"id_week":1,"id_activity":1},{"id_week":1,"id_activity":2},{"id_week":1,"id_activity":3},{"id_week":2,"id_activity":5}]}
========================
''';

void main() {
  group('.tta import', () {
    test('turns each week into a routine', () {
      final list = TtaImporter.parse(_tta);
      expect(list.map((t) => t.name), ['Normal week', 'Holiday week']);
      expect(list.every((t) => t.kind == TimetableKind.routine), isTrue);
    });

    test('maps days, times, alerts and colours', () {
      final week = TtaImporter.parse(_tta).first;
      final office = week.entries.where((e) => e.title == 'Office').toList();
      // 2..6 in that app is Monday..Friday.
      expect(office.map((e) => e.weekday).toSet(), {1, 2, 3, 4, 5});
      expect(office.first.start, 9 * 60);
      expect(office.first.end, 17 * 60);
      expect(office.first.room, 'HQ');
      expect(office.first.reminderMinutes, 15);
      expect(office.first.doNotDisturb, isTrue);
      expect(office.first.color, isNotNull);

      final wake = week.entries.singleWhere((e) => e.title == 'Wake up');
      expect(wake.weekday, DateTime.sunday);
      expect(wake.alarm, isTrue);

      final sleep = week.entries.firstWhere((e) => e.title == 'Sleep');
      expect(sleep.overnight, isTrue);
      expect(sleep.reminderMinutes, -1);
    });

    test('skips deleted activities', () {
      final all = TtaImporter.parse(_tta).expand((t) => t.entries);
      expect(all.any((e) => e.title == 'Gone'), isFalse);
    });

    test('the store recognises the format', () {
      final store = AppStore.memory();
      expect(store.importJson(_tta), contains('2 routines'));
      expect(store.timetable!.name, 'Normal week');
    });
  });

  group('overnight entries', () {
    late Timetable tt;
    setUp(() => tt = TtaImporter.parse(_tta).first);

    test('carry over into the next morning', () {
      // Tuesday 27 Oct 2026, 03:00 — still asleep since Monday night.
      final at = DateTime(2026, 10, 27, 3);
      final plan = ScheduleEngine.dayPlan(tt, at);
      expect(plan.carryOver.single.title, 'Sleep');
      expect(ScheduleEngine.current(tt, at)!.title, 'Sleep');
      expect(ScheduleEngine.current(tt, at)!.end, DateTime(2026, 10, 27, 7));
    });

    test('are only reminded once', () {
      final data = AppData(timetables: [tt])
        ..settings.dailySummary = false
        ..settings.reminderMinutes = 10;
      final plan = ReminderPlanner.plan(
        data,
        from: DateTime(2026, 10, 26),
        horizon: const Duration(days: 2),
      );
      expect(plan.where((r) => r.title.startsWith('Sleep')), isEmpty);
      expect(plan.where((r) => r.title.startsWith('Office')), hasLength(2));
    });

    test('an entry alarm rings at its start', () {
      final data = AppData(timetables: [tt])..settings.dailySummary = false;
      final plan = ReminderPlanner.plan(
        data,
        from: DateTime(2026, 10, 25),
        horizon: const Duration(days: 1),
      );
      final ring = plan.singleWhere((r) => r.kind == ReminderKind.alarm);
      expect(ring.title, 'Wake up');
      expect(ring.at, DateTime(2026, 10, 25, 7));
    });
  });

  test('do-not-disturb windows are merged', () {
    final tt = TtaImporter.parse(_tta).first;
    final data = AppData(timetables: [tt]);
    final windows = DndService.windows(data, DateTime(2026, 10, 26, 8), days: 1);
    // Office 09:00–17:00, then sleep 23:00 Mon – 07:00 Tue.
    expect(windows.first, [
      DateTime(2026, 10, 26, 9).millisecondsSinceEpoch,
      DateTime(2026, 10, 26, 17).millisecondsSinceEpoch,
    ]);
    expect(windows[1][0], DateTime(2026, 10, 26, 23).millisecondsSinceEpoch);
  });

  test('routines do not track attendance', () {
    final routine = buildSampleRoutine();
    final plan = ScheduleEngine.dayPlan(routine, DateTime(2026, 10, 26));
    expect(plan.active, isNotEmpty);
    expect(plan.active.any((o) => o.tracksAttendance), isFalse);
    expect(plan.carryOver.single.title, 'Sleep');
  });
}
