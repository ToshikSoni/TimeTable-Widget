import 'models.dart';

class AttendanceStats {
  AttendanceStats({
    required this.subject,
    required this.present,
    required this.absent,
    required this.target,
  });

  final Subject? subject;
  final int present;
  final int absent;

  /// Target percentage, e.g. 75.
  final int target;

  int get total => present + absent;
  double get ratio => total == 0 ? 1 : present / total;
  double get percent => ratio * 100;
  bool get onTrack => total == 0 || percent + 1e-9 >= target;

  /// Classes you can miss in a row and still stay at or above target.
  int get canSkip {
    if (target <= 0) return 1 << 30;
    // present / (total + x) >= target/100  =>  x <= present*100/target - total
    final x = (present * 100 / target - total).floor();
    return x < 0 ? 0 : x;
  }

  /// Classes you must attend in a row to get back to target.
  int get mustAttend {
    if (target >= 100) return absent > 0 ? 1 << 30 : 0;
    // (present + y) / (total + y) >= t  =>  y >= (t*total - present) / (1 - t)
    final t = target / 100;
    final y = ((t * total - present) / (1 - t)).ceil();
    return y < 0 ? 0 : y;
  }

  String get advice {
    if (total == 0) return 'No classes marked yet';
    if (onTrack) {
      final s = canSkip;
      if (s == 0) return 'On the edge — attend the next class';
      return 'You can skip $s more ${s == 1 ? 'class' : 'classes'}';
    }
    final m = mustAttend;
    return 'Attend the next $m ${m == 1 ? 'class' : 'classes'} to reach $target%';
  }
}

class AttendanceCalculator {
  const AttendanceCalculator._();

  static List<AttendanceStats> perSubject(Timetable tt, int target) {
    final present = <String, int>{};
    final absent = <String, int>{};
    final entrySubject = <String, String?>{
      for (final e in tt.entries) e.id: e.subjectId,
      for (final c in tt.changes)
        if (c.extra != null) c.extra!.id: c.extra!.subjectId,
    };
    tt.attendance.forEach((key, status) {
      final entryId = key.split('|').last;
      final sid = entrySubject[entryId];
      if (sid == null) return;
      if (status == AttendanceStatus.present) {
        present[sid] = (present[sid] ?? 0) + 1;
      } else if (status == AttendanceStatus.absent) {
        absent[sid] = (absent[sid] ?? 0) + 1;
      }
    });
    return [
      for (final s in tt.subjects)
        if (s.enrolled)
          AttendanceStats(
            subject: s,
            present: present[s.id] ?? 0,
            absent: absent[s.id] ?? 0,
            target: target,
          ),
    ];
  }

  static AttendanceStats overall(List<AttendanceStats> list, int target) => AttendanceStats(
    subject: null,
    present: list.fold(0, (a, s) => a + s.present),
    absent: list.fold(0, (a, s) => a + s.absent),
    target: target,
  );
}
