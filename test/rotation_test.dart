import 'dart:convert';

import 'package:cadence/core/models.dart';
import 'package:cadence/core/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2025-01-06 is a Monday.
  final weekA = DateTime(2025, 1, 6);

  Timetable alternating() => Timetable(
    name: 'Alternating',
    rotationWeeks: 2,
    rotationStart: weekA,
    entries: [
      ClassEntry(weekday: 1, start: 9 * 60, end: 10 * 60, title: 'Every week'),
      ClassEntry(weekday: 1, start: 10 * 60, end: 11 * 60, title: 'Only A', weeks: [0]),
      ClassEntry(weekday: 1, start: 11 * 60, end: 12 * 60, title: 'Only B', weeks: [1]),
    ],
  );

  List<String> titles(Timetable tt, DateTime day) =>
      ScheduleEngine.dayPlan(tt, day).active.map((o) => o.title).toList();

  test('a timetable without rotation is always week A', () {
    final tt = Timetable(name: 'Plain');
    expect(ScheduleEngine.rotationWeek(tt, weekA), 0);
    expect(ScheduleEngine.rotationWeek(tt, DateTime(2025, 3, 19)), 0);
  });

  test('weeks alternate from the anchor, forwards and backwards', () {
    final tt = alternating();
    expect(ScheduleEngine.rotationWeek(tt, weekA), 0);
    expect(ScheduleEngine.rotationWeek(tt, DateTime(2025, 1, 12)), 0, reason: 'Sunday of week A');
    expect(ScheduleEngine.rotationWeek(tt, DateTime(2025, 1, 13)), 1);
    expect(ScheduleEngine.rotationWeek(tt, DateTime(2025, 1, 20)), 0);
    expect(ScheduleEngine.rotationWeek(tt, DateTime(2024, 12, 30)), 1);
    // Across the March daylight-saving change in many regions.
    expect(ScheduleEngine.rotationWeek(tt, DateTime(2025, 3, 31)), 0);
  });

  test('only entries for the current week appear', () {
    final tt = alternating();
    expect(titles(tt, weekA), ['Every week', 'Only A']);
    expect(titles(tt, DateTime(2025, 1, 13)), ['Every week', 'Only B']);
  });

  test('a three-week cycle', () {
    final tt = alternating()..rotationWeeks = 3;
    expect(
      [
        for (var i = 0; i < 4; i++)
          ScheduleEngine.rotationWeek(tt, weekA.add(Duration(days: 7 * i))),
      ],
      [0, 1, 2, 0],
    );
  });

  test('rotationStartFor makes the given week the chosen one', () {
    final tt = alternating();
    final wednesday = DateTime(2025, 2, 5);
    tt.rotationStart = ScheduleEngine.rotationStartFor(wednesday, 1);
    expect(ScheduleEngine.rotationWeek(tt, wednesday), 1);
    expect(ScheduleEngine.rotationWeek(tt, DateTime(2025, 2, 12)), 0);
  });

  test('rotation survives a save and load', () {
    final tt = alternating();
    final back = Timetable.fromJson(jsonDecode(jsonEncode(tt.toJson())) as Map<String, dynamic>);
    expect(back.rotationWeeks, 2);
    expect(back.rotationStart, weekA);
    expect(back.entries.map((e) => e.weeks), [
      null,
      [0],
      [1],
    ]);
  });

  test('older files without rotation load as weekly', () {
    final back = Timetable.fromJson({'name': 'Old', 'entries': []});
    expect(back.rotationWeeks, 1);
    expect(back.rotates, isFalse);
  });

  test('rotation labels', () {
    expect(rotationLabel(0), 'Week A');
    expect(rotationLabel(1), 'Week B');
  });
}
