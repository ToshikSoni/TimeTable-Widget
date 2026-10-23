import 'models.dart';
import 'palette.dart';

int _t(int h, int m) => h * 60 + m;

/// The B.Tech CSE (Cyber Security) VI semester timetable, section CSE-A,
/// effective 2 January 2025. Ships as the example timetable so the app is
/// useful (and demonstrable) from the first launch.
Timetable buildSampleTimetable() {
  final teachers = {
    'CJ': Teacher(id: 't-cj', code: 'CJ', name: 'Chandani Joshi'),
    'HB': Teacher(id: 't-hb', code: 'HB', name: 'Harsh Bansal'),
    'AAB': Teacher(id: 't-aab', code: 'AAB', name: 'Anand A Bhaskar'),
    'IA': Teacher(id: 't-ia', code: 'IA', name: 'Imran Anwar'),
    'KKH': Teacher(id: 't-kkh', code: 'KKH', name: 'Kamalkant Hiran'),
    'PO': Teacher(id: 't-po', code: 'PO', name: 'Placement Office'),
  };

  final subjects = {
    'CSE2607': Subject(
      id: 's-2607',
      code: 'CSE2607',
      name: 'Software Engineering with DevOps',
      shortName: 'SE & DevOps',
      color: kSubjectPalette[0],
      teacherId: 't-cj',
    ),
    'CSE2608': Subject(
      id: 's-2608',
      code: 'CSE2608',
      name: 'Blockchain Applications',
      shortName: 'Blockchain',
      color: kSubjectPalette[3],
      teacherId: 't-hb',
    ),
    'CSE2636': Subject(
      id: 's-2636',
      code: 'CSE2636',
      name: 'Cloud Security',
      color: kSubjectPalette[1],
      teacherId: 't-kkh',
    ),
    'CSE2637': Subject(
      id: 's-2637',
      code: 'CSE2637',
      name: 'Cyber Security Testing and Assessments',
      shortName: 'Security Testing',
      color: kSubjectPalette[2],
      teacherId: 't-kkh',
    ),
    'MDE2601': Subject(
      id: 's-mde2601',
      code: 'MDE2601',
      name: 'Digital Design with Verilog',
      shortName: 'Verilog',
      color: kSubjectPalette[5],
      teacherId: 't-aab',
      room: 'NCR-01',
    ),
    'MDU6204': Subject(
      id: 's-mdu6204',
      code: 'MDU6204',
      name: 'Start-up & Entrepreneurship',
      shortName: 'Entrepreneurship',
      color: kSubjectPalette[8],
      teacherId: 't-ia',
      room: 'LT-01',
    ),
    'VAC': Subject(
      id: 's-vac',
      code: 'VAC',
      name: 'Value Added Course',
      shortName: 'VAC',
      color: kSubjectPalette[4],
      teacherId: 't-po',
      room: 'LT-01',
    ),
  };

  final periods = [
    Period(id: 'p1', label: 'Period 1', start: _t(9, 30), end: _t(10, 30)),
    Period(id: 'p2', label: 'Period 2', start: _t(10, 30), end: _t(11, 30)),
    Period(id: 'p3', label: 'Period 3', start: _t(11, 30), end: _t(12, 30)),
    Period(id: 'lunch', label: 'Lunch', start: _t(12, 30), end: _t(13, 30), isBreak: true),
    Period(id: 'p4', label: 'Period 4', start: _t(13, 30), end: _t(14, 30)),
    Period(id: 'p5', label: 'Period 5', start: _t(14, 30), end: _t(15, 30)),
    Period(id: 'p6', label: 'Period 6', start: _t(15, 30), end: _t(16, 30)),
    Period(id: 'p7', label: 'Period 7', start: _t(16, 30), end: _t(17, 30)),
  ];
  final p = {for (final x in periods) x.id: x};

  var seq = 0;
  ClassEntry c(
    int day,
    String from,
    String to,
    String subject, {
    String? room,
    ClassKind kind = ClassKind.lecture,
    String? group,
  }) => ClassEntry(
    id: 'e${++seq}',
    weekday: day,
    start: p[from]!.start,
    end: p[to]!.end,
    subjectId: subjects[subject]!.id,
    room: room,
    kind: kind,
    group: group,
  );

  ClassEntry activity(int day) => ClassEntry(
    id: 'e${++seq}',
    weekday: day,
    start: p['p6']!.start,
    end: p['p7']!.end,
    title: 'Activity / NCC / Sports / Library',
    kind: ClassKind.activity,
  );

  const mon = DateTime.monday,
      tue = DateTime.tuesday,
      wed = DateTime.wednesday,
      thu = DateTime.thursday,
      fri = DateTime.friday;
  const lab = ClassKind.lab;

  final entries = [
    // Monday
    c(mon, 'p1', 'p1', 'CSE2608', room: 'BYOD Lab'),
    c(mon, 'p2', 'p2', 'CSE2636', room: 'BYOD Lab'),
    c(mon, 'p4', 'p5', 'CSE2637', room: 'BYOD Lab', kind: lab, group: 'G1'),
    c(mon, 'p4', 'p5', 'CSE2607', room: 'Redhat Lab', kind: lab, group: 'G2'),
    // Tuesday
    c(tue, 'p1', 'p1', 'CSE2607', room: 'NCR-01'),
    c(tue, 'p2', 'p2', 'CSE2637', room: 'NCR-01'),
    c(tue, 'p3', 'p3', 'CSE2608', room: 'NCR-01'),
    c(tue, 'p4', 'p4', 'VAC'),
    c(tue, 'p5', 'p5', 'MDE2601'),
    c(tue, 'p5', 'p5', 'MDU6204'),
    c(tue, 'p6', 'p7', 'CSE2636', room: 'BYOD Lab', kind: lab, group: 'G1'),
    c(tue, 'p6', 'p7', 'CSE2608', room: 'Redhat Lab', kind: lab, group: 'G2'),
    // Wednesday
    c(wed, 'p1', 'p1', 'CSE2636', room: 'NCR-01'),
    c(wed, 'p2', 'p2', 'CSE2637', room: 'NCR-01'),
    c(wed, 'p5', 'p5', 'MDE2601'),
    c(wed, 'p5', 'p5', 'MDU6204'),
    activity(wed),
    // Thursday
    c(thu, 'p1', 'p2', 'CSE2607', room: 'Redhat Lab', kind: lab, group: 'G1'),
    c(thu, 'p1', 'p2', 'CSE2637', room: 'BYOD Lab', kind: lab, group: 'G2'),
    c(thu, 'p4', 'p4', 'VAC'),
    c(thu, 'p5', 'p5', 'MDE2601'),
    c(thu, 'p5', 'p5', 'MDU6204'),
    // Friday
    c(fri, 'p1', 'p1', 'CSE2636', room: 'BYOD Lab'),
    c(fri, 'p2', 'p2', 'CSE2607', room: 'BYOD Lab'),
    c(fri, 'p3', 'p3', 'CSE2637', room: 'BYOD Lab'),
    c(fri, 'p4', 'p5', 'CSE2608', room: 'Redhat Lab', kind: lab, group: 'G1'),
    c(fri, 'p4', 'p5', 'CSE2636', room: 'BYOD Lab', kind: lab, group: 'G2'),
    activity(fri),
  ];

  // Working Saturdays, each following a weekday's timetable.
  SpecialDay follow(int month, int day, int weekday) => SpecialDay(
    id: 'sat-$month-$day',
    date: DateTime(2025, month, day),
    type: SpecialDayType.followDay,
    followWeekday: weekday,
    label: 'Working Saturday',
  );

  final specialDays = [
    follow(1, 4, mon),
    follow(2, 8, mon),
    follow(3, 22, mon),
    follow(1, 11, tue),
    follow(2, 15, tue),
    follow(3, 29, tue),
    follow(1, 18, wed),
    follow(2, 22, wed),
    follow(4, 5, wed),
    follow(1, 25, thu),
    follow(3, 1, thu),
    follow(4, 12, thu),
    follow(2, 1, fri),
    follow(3, 8, fri),
  ];

  return Timetable(
    id: 'sample-cse-a',
    name: 'B.Tech CSE · Semester VI',
    institution: 'Sir Padampat Singhania University',
    section: 'CSE-A (Cyber Security)',
    validFrom: DateTime(2025, 1, 2),
    workingDays: const [mon, tue, wed, thu, fri],
    periods: periods,
    subjects: subjects.values.toList(),
    teachers: teachers.values.toList(),
    entries: entries,
    specialDays: specialDays,
    groups: ['G1', 'G2'],
    myGroup: 'G1',
  );
}

/// A starter bell schedule for blank timetables.
List<Period> defaultPeriods() => [
  Period(label: 'Period 1', start: _t(9, 0), end: _t(10, 0)),
  Period(label: 'Period 2', start: _t(10, 0), end: _t(11, 0)),
  Period(label: 'Period 3', start: _t(11, 15), end: _t(12, 15)),
  Period(label: 'Lunch', start: _t(12, 15), end: _t(13, 0), isBreak: true),
  Period(label: 'Period 4', start: _t(13, 0), end: _t(14, 0)),
  Period(label: 'Period 5', start: _t(14, 0), end: _t(15, 0)),
  Period(label: 'Period 6', start: _t(15, 0), end: _t(16, 0)),
];

/// A made-up working week: the example for people using Cadence to plan their
/// day rather than a school timetable.
Timetable buildSampleRoutine() {
  var seq = 0;
  const weekdays = [1, 2, 3, 4, 5];
  const everyDay = [1, 2, 3, 4, 5, 6, 7];
  final entries = <ClassEntry>[];
  void add(
    List<int> days,
    String title,
    int start,
    int end, {
    required int color,
    String? place,
    String? note,
    bool alarm = false,
    bool quiet = false,
    int? remind,
  }) {
    for (final d in days) {
      entries.add(
        ClassEntry(
          id: 'r${++seq}',
          weekday: d,
          start: start,
          end: end,
          title: title,
          room: place,
          note: note,
          kind: ClassKind.activity,
          color: kRoutinePalette[color],
          alarm: alarm,
          doNotDisturb: quiet,
          reminderMinutes: remind,
        ),
      );
    }
  }

  const day = 24 * 60;
  add(weekdays, 'Wake up & stretch', _t(6, 45), _t(7, 0), color: 3, alarm: true, remind: 0);
  add([1, 3, 5], 'Workout', _t(7, 0), _t(7, 45), color: 4, place: 'Gym');
  add([2, 4], 'Morning walk', _t(7, 0), _t(7, 30), color: 12);
  add(weekdays, 'Breakfast', _t(8, 0), _t(8, 30), color: 8);
  add(weekdays, 'Commute', _t(8, 45), _t(9, 30), color: 15, note: 'Podcast or audiobook');
  add(weekdays, 'Deep work', _t(9, 30), _t(12, 30), color: 0, place: 'Office', quiet: true);
  add(weekdays, 'Lunch', _t(12, 30), _t(13, 15), color: 8);
  add(weekdays, 'Meetings & email', _t(13, 15), _t(15, 0), color: 6, place: 'Office');
  add(weekdays, 'Focus block', _t(15, 0), _t(17, 30), color: 13, place: 'Office', quiet: true);
  add(weekdays, 'Commute home', _t(17, 45), _t(18, 30), color: 15);
  add(everyDay, 'Cook & dinner', _t(19, 0), _t(20, 0), color: 9);
  add(
    [1, 2, 3, 4],
    'Learn something new',
    _t(20, 30),
    _t(21, 30),
    color: 5,
    note: 'Course, book or side project',
  );
  add([1, 2, 3, 4, 7], 'Wind down, no screens', _t(22, 30), _t(23, 0), color: 14);
  add([1, 2, 3, 4, 7], 'Sleep', _t(23, 0), day + _t(6, 45), color: 11, quiet: true, remind: -1);
  add([5, 6], 'Sleep', _t(23, 30), day + _t(8, 0), color: 11, quiet: true, remind: -1);
  add([6], 'Long run', _t(8, 30), _t(9, 45), color: 4, place: 'Park');
  add([6], 'Groceries & chores', _t(10, 30), _t(12, 0), color: 7);
  add([7], 'Family & friends', _t(16, 0), _t(19, 0), color: 2);
  add([7], 'Plan the week ahead', _t(20, 0), _t(20, 30), color: 1);

  return Timetable(
    id: 'sample-routine',
    name: 'Workday routine (example)',
    kind: TimetableKind.routine,
    workingDays: everyDay,
    entries: entries,
  );
}
