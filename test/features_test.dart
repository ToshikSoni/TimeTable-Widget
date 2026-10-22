import 'dart:convert';

import 'package:cadence/core/attendance.dart';
import 'package:cadence/core/ics.dart';
import 'package:cadence/core/models.dart';
import 'package:cadence/core/reminders.dart';
import 'package:cadence/core/sample_data.dart';
import 'package:cadence/core/store.dart';
import 'package:cadence/services/home_widget_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('attendance', () {
    AttendanceStats stats(int present, int absent) =>
        AttendanceStats(subject: null, present: present, absent: absent, target: 75);

    test('works out how many classes can be skipped', () {
      expect(stats(9, 1).canSkip, 2); // 9/12 = 75%
      expect(stats(3, 1).canSkip, 0);
      expect(stats(9, 1).onTrack, isTrue);
    });

    test('works out how many classes are needed to recover', () {
      final s = stats(5, 5);
      expect(s.onTrack, isFalse);
      expect(s.mustAttend, 10); // 15/20 = 75%
    });

    test('counts per subject from records', () {
      final tt = buildSampleTimetable();
      tt.attendance['2025-01-06|e1'] = AttendanceStatus.present; // CSE2608
      tt.attendance['2025-01-07|e7'] = AttendanceStatus.absent; // CSE2608
      final list = AttendanceCalculator.perSubject(tt, 75);
      final blockchain = list.firstWhere((s) => s.subject!.code == 'CSE2608');
      expect(blockchain.present, 1);
      expect(blockchain.absent, 1);
    });
  });

  group('reminders', () {
    test('plans class reminders, the summary and the alarm', () {
      final data = AppData(timetables: [buildSampleTimetable()]);
      data.settings
        ..reminderMinutes = 10
        ..morningAlarm = true
        ..morningAlarmLead = 60;
      final plan = ReminderPlanner.plan(
        data,
        from: DateTime(2025, 1, 6),
        horizon: const Duration(days: 1),
      );
      final alarm = plan.firstWhere((r) => r.kind == ReminderKind.alarm);
      expect(alarm.at, DateTime(2025, 1, 6, 8, 30));
      final summary = plan.firstWhere((r) => r.kind == ReminderKind.summary);
      expect(summary.at, DateTime(2025, 1, 6, 7, 30));
      final firstClass = plan.firstWhere((r) => r.kind == ReminderKind.classSoon);
      expect(firstClass.at, DateTime(2025, 1, 6, 9, 20));
      expect(firstClass.title, contains('Blockchain'));
    });

    test('ids are stable and distinct', () {
      final data = AppData(timetables: [buildSampleTimetable()]);
      List<int> ids() =>
          ReminderPlanner.plan(data, from: DateTime(2025, 1, 6)).map((r) => r.id).toList();
      final a = ids();
      expect(a, ids());
      expect(a.toSet().length, a.length);
    });

    test('subjects can opt out', () {
      final tt = buildSampleTimetable();
      final i = tt.subjects.indexWhere((s) => s.code == 'CSE2608');
      tt.subjects[i] = tt.subjects[i].copyWith(reminderMinutes: -1);
      final data = AppData(timetables: [tt])..settings.dailySummary = false;
      final plan = ReminderPlanner.plan(
        data,
        from: DateTime(2025, 1, 6),
        horizon: const Duration(days: 1),
      );
      expect(plan.any((r) => r.title.contains('Blockchain')), isFalse);
    });
  });

  test('ICS export contains events and escapes text', () {
    final tt = buildSampleTimetable();
    final ics = buildIcs(
      tt,
      from: DateTime(2025, 1, 6),
      to: DateTime(2025, 1, 6),
      now: DateTime.utc(2025),
    );
    expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
    expect('BEGIN:VEVENT'.allMatches(ics).length, 3);
    expect(ics, contains('DTSTART:20250106T093000'));
    expect(ics, contains(r'LOCATION:BYOD Lab'));
  });

  test('widget payload lists upcoming classes with absolute times', () {
    final data = AppData(timetables: [buildSampleTimetable()]);
    final payload = HomeWidgetSync.buildPayload(
      data,
      now: DateTime(2025, 1, 6, 8),
      use24h: true,
      days: 1,
    );
    final events = (payload['events'] as List).cast<Map>();
    expect(events, hasLength(3));
    expect(events.first['s'], DateTime(2025, 1, 6, 9, 30).millisecondsSinceEpoch);
    expect(events.first['c'], 'CSE2608');
    expect(jsonEncode(payload), isNotEmpty);
  });

  group('store', () {
    test('imports a shared timetable as a new one', () {
      final source = AppStore.memory()..loadSample();
      final shared = source.exportTimetable(source.timetable!);

      final target = AppStore.memory()..loadSample();
      final message = target.importJson(shared);
      expect(message, startsWith('Added'));
      expect(target.data.timetables, hasLength(2));
      expect(target.data.timetables[0].id, isNot(target.data.timetables[1].id));
    });

    test('rejects unrelated files', () {
      expect(() => AppStore.memory().importJson('[1, 2, 3]'), throwsFormatException);
      expect(() => AppStore.memory().importJson('{"hello": "world"}'), throwsFormatException);
    });

    test('toggling a cancellation twice restores the class', () {
      final store = AppStore.memory()..loadSample();
      final day = DateTime(2025, 1, 6);
      store.toggleCancelled(day, 'e1');
      expect(store.timetable!.changes, hasLength(1));
      store.toggleCancelled(day, 'e1');
      expect(store.timetable!.changes, isEmpty);
    });
  });
}
