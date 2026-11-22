import 'models.dart';

enum SearchKind { entry, subject, teacher, task }

/// One match from [searchData].
class SearchHit {
  SearchHit(this.kind, this.score, {this.entry, this.subject, this.teacher, this.task});

  final SearchKind kind;

  /// Higher is better.
  final int score;
  final ClassEntry? entry;
  final Subject? subject;
  final Teacher? teacher;
  final StudyTask? task;
}

/// Finds classes, subjects, people and tasks matching [query] in the active
/// timetable. Every word of the query has to match somewhere (name, code,
/// room, teacher, day…), so "lab fri" finds Friday's labs.
List<SearchHit> searchData(AppData data, String query, {int limit = 40}) {
  final words = _normalise(query).split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];
  final tt = data.active;
  final hits = <SearchHit>[];

  int? score(List<String?> primary, List<String?> secondary) {
    final p = primary.whereType<String>().map(_normalise).toList();
    final s = secondary.whereType<String>().map(_normalise).toList();
    var total = 0;
    for (final w in words) {
      var best = 0;
      for (final f in p) {
        if (f == w) {
          best = 100;
        } else if (f.startsWith(w) || f.contains(' $w')) {
          best = best < 60 ? 60 : best;
        } else if (f.contains(w)) {
          best = best < 30 ? 30 : best;
        }
      }
      for (final f in s) {
        if (best >= 20) break;
        if (f.split(' ').any((x) => x.startsWith(w))) {
          best = 20;
        } else if (f.contains(w)) {
          best = best < 10 ? 10 : best;
        }
      }
      if (best == 0) return null;
      total += best;
    }
    return total;
  }

  if (tt != null) {
    for (final s in tt.subjects) {
      final teacher = tt.teacher(s.teacherId);
      final v = score([s.name, s.code, s.shortName], [s.room, teacher?.name, teacher?.code]);
      if (v != null) hits.add(SearchHit(SearchKind.subject, v + 5, subject: s));
    }
    for (final t in tt.teachers) {
      final v = score([t.name, t.code], [t.email, t.notes]);
      if (v != null) hits.add(SearchHit(SearchKind.teacher, v + 3, teacher: t));
    }
    for (final e in tt.entries) {
      final subject = tt.subject(e.subjectId);
      final teacher = tt.teacher(e.teacherId) ?? tt.teacher(subject?.teacherId);
      final v = score(
        [subject?.name, subject?.code, subject?.shortName, e.title],
        [
          e.room ?? subject?.room,
          teacher?.name,
          teacher?.code,
          e.kind.label,
          if (e.group != null) 'group ${e.group}',
          e.note,
          _weekdays[e.weekday - 1],
        ],
      );
      if (v != null) hits.add(SearchHit(SearchKind.entry, v, entry: e));
    }
  }
  for (final t in data.tasks) {
    final subject = tt?.subject(t.subjectId);
    final v = score([t.title], [t.type.label, subject?.name, subject?.code, t.notes]);
    if (v != null) hits.add(SearchHit(SearchKind.task, v + (t.done ? -5 : 2), task: t));
  }

  hits.sort((a, b) {
    final s = b.score.compareTo(a.score);
    if (s != 0) return s;
    final ea = a.entry, eb = b.entry;
    if (ea != null && eb != null) {
      final d = ea.weekday.compareTo(eb.weekday);
      return d != 0 ? d : ea.start.compareTo(eb.start);
    }
    return a.kind.index.compareTo(b.kind.index);
  });
  return hits.take(limit).toList();
}

const _weekdays = [
  'monday mon',
  'tuesday tue',
  'wednesday wed',
  'thursday thu',
  'friday fri',
  'saturday sat',
  'sunday sun',
];

String _normalise(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ').trim();
