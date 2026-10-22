import 'package:cadence/core/models.dart';
import 'package:cadence/core/sample_data.dart';
import 'package:cadence/core/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Timetable tt;

  setUp(() => tt = buildSampleTimetable());

  // 2025-01-06 is a Monday.
  final monday = DateTime(2025, 1, 6);
  final tuesday = DateTime(2025, 1, 7);

  group('day plan', () {
    test('only shows labs for my group', () {
      tt.myGroup = 'G1';
      final titles = ScheduleEngine.dayPlan(tt, monday).active.map((o) => o.code).toList();
      expect(titles, ['CSE2608', 'CSE2636', 'CSE2637']);

      tt.myGroup = 'G2';
      final g2 = ScheduleEngine.dayPlan(tt, monday).active.map((o) => o.code).toList();
      expect(g2, ['CSE2608', 'CSE2636', 'CSE2607']);
    });

    test('shows every group when none is chosen', () {
      tt.myGroup = null;
      expect(ScheduleEngine.dayPlan(tt, monday).active, hasLength(4));
    });

    test('hides electives that are not enrolled', () {
      final both = ScheduleEngine.dayPlan(tt, tuesday).active.map((o) => o.code);
      expect(both, containsAll(['MDE2601', 'MDU6204']));

      final i = tt.subjects.indexWhere((s) => s.code == 'MDU6204');
      tt.subjects[i] = tt.subjects[i].copyWith(enrolled: false);
      final one = ScheduleEngine.dayPlan(tt, tuesday).active.map((o) => o.code);
      expect(one, contains('MDE2601'));
      expect(one, isNot(contains('MDU6204')));
    });

    test('a working Saturday follows the given weekday', () {
      // 4 January 2025 follows Monday.
      final plan = ScheduleEngine.dayPlan(tt, DateTime(2025, 1, 4));
      expect(plan.followsOtherDay, isTrue);
      expect(plan.effectiveWeekday, DateTime.monday);
      expect(plan.active.first.code, 'CSE2608');
      expect(plan.active.first.start, DateTime(2025, 1, 4, 9, 30));
    });

    test('holidays have no classes', () {
      tt.specialDays.add(SpecialDay(date: monday, type: SpecialDayType.holiday, label: 'Test'));
      final plan = ScheduleEngine.dayPlan(tt, monday);
      expect(plan.isHoliday, isTrue);
      expect(plan.occurrences, isEmpty);
    });

    test('nothing before the timetable starts', () {
      final plan = ScheduleEngine.dayPlan(tt, DateTime(2024, 12, 30));
      expect(plan.outOfRange, isTrue);
      expect(plan.occurrences, isEmpty);
    });

    test('cancelled classes stay visible but inactive', () {
      final first = ScheduleEngine.dayPlan(tt, monday).active.first;
      tt.changes.add(ClassChange(date: monday, type: ChangeType.cancel, entryId: first.entry.id));
      final plan = ScheduleEngine.dayPlan(tt, monday);
      expect(plan.occurrences.first.cancelled, isTrue);
      expect(plan.active.map((o) => o.entry.id), isNot(contains(first.entry.id)));
    });

    test('extra classes are added on their date only', () {
      final extra = ClassEntry(weekday: 1, start: 18 * 60, end: 19 * 60, subjectId: 's-2636');
      tt.changes.add(ClassChange(date: monday, type: ChangeType.extra, extra: extra));
      expect(ScheduleEngine.dayPlan(tt, monday).active.last.extra, isTrue);
      expect(
        ScheduleEngine.dayPlan(tt, monday.add(const Duration(days: 7))).active.any((o) => o.extra),
        isFalse,
      );
    });
  });

  group('now and next', () {
    test('finds the live class and the next one', () {
      final at = DateTime(2025, 1, 6, 10, 0);
      expect(ScheduleEngine.current(tt, at)?.code, 'CSE2608');
      expect(ScheduleEngine.next(tt, at)?.code, 'CSE2636');
    });

    test('next skips over the weekend', () {
      final fridayEvening = DateTime(2025, 1, 10, 20);
      final next = ScheduleEngine.next(tt, fridayEvening)!;
      // Saturday 11 January follows Tuesday.
      expect(next.date, DateTime(2025, 1, 11));
      expect(next.code, 'CSE2607');
    });

    test('free slots include the lunch break', () {
      final plan = ScheduleEngine.dayPlan(tt, monday);
      final gaps = ScheduleEngine.freeSlots(plan);
      expect(gaps.first.start, DateTime(2025, 1, 6, 11, 30));
      expect(gaps.first.end, DateTime(2025, 1, 6, 13, 30));
    });
  });

  test('overlapping classes are laid out side by side', () {
    tt.myGroup = null;
    final plan = ScheduleEngine.dayPlan(tt, tuesday);
    final lanes = ScheduleEngine.layoutLanes(plan.occurrences);
    final electives = plan.occurrences.where((o) => o.code.startsWith('MD')).toList();
    expect(electives, hasLength(2));
    expect(lanes[electives[0]]!.lanes, 2);
    expect({lanes[electives[0]]!.lane, lanes[electives[1]]!.lane}, {0, 1});
    final first = plan.occurrences.first;
    expect(lanes[first]!.lanes, 1);
  });

  test('JSON round-trip keeps everything', () {
    tt.attendance['2025-01-06|e1'] = AttendanceStatus.present;
    final data = AppData(
      timetables: [tt],
      tasks: [StudyTask(title: 'Lab record', due: DateTime(2025, 1, 8, 9))],
    );
    final copy = AppData.fromJson(data.toJson());
    expect(copy.toJson(), data.toJson());
    expect(copy.active!.entries, hasLength(tt.entries.length));
  });
}
