import 'models.dart';

/// A concrete class on a specific date, with everything resolved
/// (subject, teacher, room, groups, overrides).
class Occurrence {
  Occurrence({
    required this.date,
    required this.entry,
    required this.subject,
    required this.teacher,
    this.cancelled = false,
    this.extra = false,
    this.changeReason,
  });

  final DateTime date;
  final ClassEntry entry;
  final Subject? subject;
  final Teacher? teacher;
  final bool cancelled;
  final bool extra;
  final String? changeReason;

  DateTime get start => date.add(Duration(minutes: entry.start));
  DateTime get end => date.add(Duration(minutes: entry.end));

  String get title {
    final t = entry.title;
    if (subject != null) return subject!.name;
    if (t != null && t.isNotEmpty) return t;
    return entry.kind.label;
  }

  String get shortTitle => subject?.label ?? title;
  String get code => subject?.code ?? '';
  String? get room {
    final r = entry.room;
    if (r != null && r.isNotEmpty) return r;
    return subject?.room;
  }

  int get color => entry.color ?? subject?.color ?? kActivityColor;

  String get key => attendanceKey(date, entry.id);

  /// Whether this occurrence counts towards attendance.
  bool get tracksAttendance => subject != null && entry.kind != ClassKind.activity && !cancelled;

  bool isLiveAt(DateTime t) => !cancelled && !t.isBefore(start) && t.isBefore(end);

  double progressAt(DateTime t) {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    return (t.difference(start).inSeconds / total).clamp(0.0, 1.0);
  }
}

const kActivityColor = 0xFF8A8F98;

class DayPlan {
  DayPlan({
    required this.date,
    required this.occurrences,
    this.special,
    this.effectiveWeekday,
    this.outOfRange = false,
    this.carryOver = const [],
  });

  final DateTime date;
  final List<Occurrence> occurrences;

  /// Yesterday's overnight entries that are still running into this day
  /// (e.g. sleep from 23:30). Not part of [occurrences], so they aren't
  /// counted or reminded twice.
  final List<Occurrence> carryOver;
  final SpecialDay? special;

  /// The weekday whose timetable is followed (differs from [date] on
  /// "follows Monday" days).
  final int? effectiveWeekday;
  final bool outOfRange;

  bool get isHoliday => special?.type == SpecialDayType.holiday;
  bool get followsOtherDay =>
      special?.type == SpecialDayType.followDay && special?.followWeekday != null;

  List<Occurrence> get active => occurrences.where((o) => !o.cancelled).toList();

  DateTime? get firstStart => active.isEmpty ? null : active.first.start;
  DateTime? get lastEnd =>
      active.isEmpty ? null : active.map((o) => o.end).reduce((a, b) => a.isAfter(b) ? a : b);
}

class ScheduleEngine {
  const ScheduleEngine._();

  static SpecialDay? specialDayFor(Timetable tt, DateTime date) {
    final key = dateKey(date);
    for (final d in tt.specialDays) {
      if (dateKey(d.date) == key) return d;
    }
    return null;
  }

  static bool isVisible(Timetable tt, ClassEntry e) {
    final subject = tt.subject(e.subjectId);
    if (subject != null && !subject.enrolled) return false;
    if (e.group != null && tt.myGroup != null && e.group != tt.myGroup) {
      return false;
    }
    return true;
  }

  /// Weekly entries for [weekday] after group and elective filtering.
  static List<ClassEntry> entriesFor(Timetable tt, int weekday, {bool filtered = true}) {
    final list =
        tt.entries.where((e) => e.weekday == weekday && (!filtered || isVisible(tt, e))).toList()
          ..sort(_byTime);
    return list;
  }

  static DayPlan dayPlan(Timetable tt, DateTime day) {
    final plan = _plan(tt, day);
    final previous = _plan(tt, DateTime(plan.date.year, plan.date.month, plan.date.day - 1));
    final carry = previous.active.where((o) => o.entry.overnight).toList();
    if (carry.isEmpty) return plan;
    return DayPlan(
      date: plan.date,
      occurrences: plan.occurrences,
      special: plan.special,
      effectiveWeekday: plan.effectiveWeekday,
      outOfRange: plan.outOfRange,
      carryOver: carry,
    );
  }

  static DayPlan _plan(Timetable tt, DateTime day) {
    final date = dateOnly(day);
    if ((tt.validFrom != null && date.isBefore(dateOnly(tt.validFrom!))) ||
        (tt.validUntil != null && date.isAfter(dateOnly(tt.validUntil!)))) {
      return DayPlan(date: date, occurrences: const [], outOfRange: true);
    }

    final special = specialDayFor(tt, date);
    if (special?.type == SpecialDayType.holiday) {
      return DayPlan(date: date, occurrences: const [], special: special);
    }
    final weekday = special?.type == SpecialDayType.followDay && special?.followWeekday != null
        ? special!.followWeekday!
        : date.weekday;

    final key = dateKey(date);
    final changes = tt.changes.where((c) => dateKey(c.date) == key).toList();
    final cancelled = {
      for (final c in changes)
        if (c.type == ChangeType.cancel && c.entryId != null) c.entryId!: c,
    };

    final result = <Occurrence>[
      for (final e in entriesFor(tt, weekday))
        Occurrence(
          date: date,
          entry: e,
          subject: tt.subject(e.subjectId),
          teacher: tt.teacher(e.teacherId) ?? tt.teacher(tt.subject(e.subjectId)?.teacherId),
          cancelled: cancelled.containsKey(e.id),
          changeReason: cancelled[e.id]?.reason,
        ),
      for (final c in changes)
        if (c.type == ChangeType.extra && c.extra != null && isVisible(tt, c.extra!))
          Occurrence(
            date: date,
            entry: c.extra!,
            subject: tt.subject(c.extra!.subjectId),
            teacher:
                tt.teacher(c.extra!.teacherId) ??
                tt.teacher(tt.subject(c.extra!.subjectId)?.teacherId),
            extra: true,
            changeReason: c.reason,
          ),
    ]..sort((a, b) => _byTime(a.entry, b.entry));

    return DayPlan(date: date, occurrences: result, special: special, effectiveWeekday: weekday);
  }

  static int _byTime(ClassEntry a, ClassEntry b) {
    final s = a.start.compareTo(b.start);
    return s != 0 ? s : a.end.compareTo(b.end);
  }

  /// Every non-cancelled occurrence between [from] and [to] (inclusive days).
  static List<Occurrence> occurrencesBetween(Timetable tt, DateTime from, DateTime to) {
    final out = <Occurrence>[];
    var day = dateOnly(from);
    final last = dateOnly(to);
    while (!day.isAfter(last)) {
      out.addAll(_plan(tt, day).active);
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return out;
  }

  static Occurrence? current(Timetable tt, DateTime now) {
    final plan = dayPlan(tt, now);
    // When blocks overlap (e.g. "Work" with a meeting inside it), show the
    // one that started most recently; ties keep timetable order.
    Occurrence? best;
    for (final o in [...plan.carryOver, ...plan.active]) {
      if (o.isLiveAt(now) && (best == null || o.start.isAfter(best.start))) best = o;
    }
    return best;
  }

  /// The next class starting after [now], looking up to [days] ahead.
  static Occurrence? next(Timetable tt, DateTime now, {int days = 14}) {
    var day = dateOnly(now);
    for (var i = 0; i <= days; i++) {
      for (final o in _plan(tt, day).active) {
        if (o.start.isAfter(now)) return o;
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return null;
  }

  /// Gaps of at least [minMinutes] between classes on a day.
  static List<FreeSlot> freeSlots(DayPlan plan, {int minMinutes = 20}) {
    final list = plan.active;
    final gaps = <FreeSlot>[];
    for (var i = 0; i + 1 < list.length; i++) {
      final end = list.take(i + 1).map((o) => o.end).reduce((a, b) => a.isAfter(b) ? a : b);
      final nextStart = list[i + 1].start;
      if (nextStart.difference(end).inMinutes >= minMinutes) {
        gaps.add(FreeSlot(end, nextStart));
      }
    }
    return gaps;
  }

  /// Groups occurrences that overlap in time into lanes for side-by-side
  /// rendering. Returns for each occurrence its lane index and lane count.
  static Map<Occurrence, ({int lane, int lanes})> layoutLanes(List<Occurrence> items) =>
      layoutSegments(items, (o) => o.entry.start, (o) => o.entry.end);

  /// Lane layout for arbitrary items with start/end minutes.
  static Map<T, ({int lane, int lanes})> layoutSegments<T>(
    List<T> items,
    int Function(T) startOf,
    int Function(T) endOf,
  ) {
    final sorted = [...items]
      ..sort((a, b) {
        final s = startOf(a).compareTo(startOf(b));
        return s != 0 ? s : endOf(a).compareTo(endOf(b));
      });
    final result = <T, ({int lane, int lanes})>{};
    var cluster = <T>[];
    var clusterEnd = -1;
    final laneEnds = <int>[];
    final assigned = <T, int>{};

    void flush() {
      final count = laneEnds.length;
      for (final o in cluster) {
        result[o] = (lane: assigned[o]!, lanes: count);
      }
      cluster = [];
      laneEnds.clear();
    }

    for (final o in sorted) {
      final start = startOf(o), end = endOf(o);
      if (cluster.isNotEmpty && start >= clusterEnd) {
        flush();
        clusterEnd = -1;
      }
      var lane = laneEnds.indexWhere((e) => e <= start);
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(end);
      } else {
        laneEnds[lane] = end;
      }
      assigned[o] = lane;
      cluster.add(o);
      if (end > clusterEnd) clusterEnd = end;
    }
    if (cluster.isNotEmpty) flush();
    return result;
  }
}

class FreeSlot {
  FreeSlot(this.start, this.end);
  final DateTime start;
  final DateTime end;
  Duration get duration => end.difference(start);
}
