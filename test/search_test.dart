import 'package:cadence/core/models.dart';
import 'package:cadence/core/sample_data.dart';
import 'package:cadence/core/search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppData data;

  setUp(() {
    final tt = buildSampleTimetable();
    data = AppData(
      timetables: [tt],
      activeTimetableId: tt.id,
      tasks: [StudyTask(title: 'Cloud security assignment 2')],
    );
  });

  test('an empty query finds nothing', () {
    expect(searchData(data, '   '), isEmpty);
  });

  test('finds a subject by its code', () {
    final hits = searchData(data, 'cse2608');
    expect(hits.first.kind, SearchKind.subject);
    expect(hits.first.subject!.code, 'CSE2608');
  });

  test('every word must match', () {
    final hits = searchData(data, 'lab mon');
    expect(hits, isNotEmpty);
    for (final h in hits) {
      expect(h.kind, SearchKind.entry);
      expect(h.entry!.weekday, 1);
    }
  });

  test('finds tasks', () {
    final hits = searchData(data, 'assignment');
    expect(hits.any((h) => h.kind == SearchKind.task), isTrue);
  });

  test('nonsense finds nothing', () {
    expect(searchData(data, 'zzqx'), isEmpty);
  });
}
