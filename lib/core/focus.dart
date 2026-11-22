import 'models.dart';

enum FocusPhase {
  focus('Focus'),
  shortBreak('Short break'),
  longBreak('Long break');

  const FocusPhase(this.label);
  final String label;

  bool get isBreak => this != FocusPhase.focus;
}

/// A finished stretch of focused work, kept for the focus history.
class FocusSession {
  FocusSession({String? id, required this.start, required this.minutes, this.subjectId, this.label})
    : id = id ?? newId();

  final String id;
  final DateTime start;
  final int minutes;

  /// Subject (or routine category) the time was spent on, if any.
  final String? subjectId;

  /// Free-text label for sessions without a subject, e.g. "Reading".
  final String? label;

  DateTime get end => start.add(Duration(minutes: minutes));

  Map<String, dynamic> toJson() => {
    'id': id,
    'start': start.toIso8601String(),
    'minutes': minutes,
    if (subjectId != null) 'subjectId': subjectId,
    if (label != null) 'label': label,
  };

  factory FocusSession.fromJson(Map<String, dynamic> j) => FocusSession(
    id: j['id'] as String?,
    start: DateTime.tryParse(j['start'] as String? ?? '') ?? DateTime.now(),
    minutes: j['minutes'] as int? ?? 0,
    subjectId: j['subjectId'] as String?,
    label: j['label'] as String?,
  );
}

/// The longest history kept; older sessions are dropped first.
const maxFocusSessions = 3000;

/// Summaries of the focus history for the focus screen.
class FocusStats {
  const FocusStats._();

  /// Total minutes for each of the [days] days ending on [today], oldest
  /// first.
  static List<int> dailyMinutes(List<FocusSession> log, DateTime today, {int days = 7}) {
    final first = DateTime(today.year, today.month, today.day - (days - 1));
    final totals = List.filled(days, 0);
    for (final s in log) {
      final d = dateOnly(s.start);
      if (d.isBefore(first)) continue;
      final i = _daysBetween(first, d);
      if (i >= 0 && i < days) totals[i] += s.minutes;
    }
    return totals;
  }

  static int minutesOn(List<FocusSession> log, DateTime day) {
    final d = dateOnly(day);
    return log.where((s) => dateOnly(s.start) == d).fold(0, (a, s) => a + s.minutes);
  }

  /// Consecutive days with at least one session, counting back from today
  /// (or from yesterday when nothing has been logged today yet).
  static int streak(List<FocusSession> log, DateTime today) {
    final days = {for (final s in log) dateOnly(s.start)};
    var day = dateOnly(today);
    if (!days.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
    var count = 0;
    while (days.contains(day)) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  /// Minutes per subject id (`null` for unlinked sessions) since [from],
  /// largest first.
  static List<MapEntry<String?, int>> bySubject(List<FocusSession> log, DateTime from) {
    final totals = <String?, int>{};
    for (final s in log) {
      if (s.start.isBefore(from)) continue;
      totals[s.subjectId] = (totals[s.subjectId] ?? 0) + s.minutes;
    }
    return totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  static int _daysBetween(DateTime a, DateTime b) =>
      (DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)))
          .inDays;
}
