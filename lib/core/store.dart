import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'sample_data.dart';
import 'tta_import.dart';

/// Owns the app's data, persists it as JSON and notifies listeners on change.
///
/// Everything lives in a single human-readable file so backups are trivial
/// and nothing ever leaves the device.
class AppStore extends ChangeNotifier {
  AppStore._(this._file, this.data);

  static const fileName = 'cadence.json';

  final File? _file;
  AppData data;
  Timer? _saveTimer;

  /// Creates an in-memory store (used by tests and previews).
  factory AppStore.memory([AppData? data]) => AppStore._(null, data ?? AppData());

  static Future<File> defaultFile() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  static Future<AppStore> open([File? file]) async {
    final f = file ?? await defaultFile();
    return AppStore._(f, await _read(f));
  }

  static Future<AppData> _read(File f) async {
    for (final candidate in [f, File('${f.path}.bak')]) {
      try {
        if (await candidate.exists()) {
          final raw = await candidate.readAsString();
          return AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        }
      } catch (e) {
        debugPrint('Could not read ${candidate.path}: $e');
      }
    }
    return AppData();
  }

  /// Re-reads data from disk; used when another isolate wrote the file.
  Future<void> reload() async {
    if (_file == null) return;
    data = await _read(_file);
    notifyListeners();
  }

  Settings get settings => data.settings;
  Timetable? get timetable => data.active;

  void update(void Function(AppData d) change) {
    change(data);
    _changed();
  }

  void updateTimetable(void Function(Timetable t) change) {
    final t = data.active;
    if (t == null) return;
    change(t);
    _changed();
  }

  void updateSettings(void Function(Settings s) change) {
    change(data.settings);
    _changed();
  }

  void _changed() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), flush);
  }

  /// Writes pending changes now. Writes go to a temp file first and the
  /// previous version is kept as `.bak`, so a crash can't corrupt data.
  Future<void> flush() async {
    _saveTimer?.cancel();
    final f = _file;
    if (f == null) return;
    final json = const JsonEncoder.withIndent('  ').convert(data.toJson());
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    if (await f.exists()) {
      try {
        await f.copy('${f.path}.bak');
      } catch (_) {}
    }
    await tmp.rename(f.path);
  }

  // Timetables -------------------------------------------------------------

  void addTimetable(Timetable t, {bool activate = true}) => update((d) {
    d.timetables.add(t);
    if (activate) d.activeTimetableId = t.id;
  });

  void setActive(String id) => update((d) => d.activeTimetableId = id);

  void removeTimetable(String id) => update((d) {
    d.timetables.removeWhere((t) => t.id == id);
    if (d.activeTimetableId == id) {
      d.activeTimetableId = d.timetables.isEmpty ? null : d.timetables.first.id;
    }
  });

  void loadSample({bool routine = false}) {
    final sample = routine ? buildSampleRoutine() : buildSampleTimetable();
    addTimetable(
      data.timetables.any((t) => t.id == sample.id) ? sample.duplicate(sample.name) : sample,
    );
  }

  // Subjects, teachers, entries -------------------------------------------

  void upsertSubject(Subject s) => updateTimetable((t) => _upsert(t.subjects, s, (x) => x.id));
  void removeSubject(String id) => updateTimetable((t) {
    t.subjects.removeWhere((s) => s.id == id);
    t.entries.removeWhere((e) => e.subjectId == id);
  });

  void upsertTeacher(Teacher x) => updateTimetable((t) => _upsert(t.teachers, x, (y) => y.id));
  void removeTeacher(String id) => updateTimetable((t) {
    t.teachers.removeWhere((x) => x.id == id);
    t.subjects = [
      for (final s in t.subjects) s.teacherId == id ? s.copyWith(clearTeacher: true) : s,
    ];
    t.entries = [for (final e in t.entries) e.teacherId == id ? e.copyWith(clearTeacher: true) : e];
  });

  void upsertEntry(ClassEntry e) => updateTimetable((t) => _upsert(t.entries, e, (x) => x.id));
  void removeEntry(String id) => updateTimetable((t) => t.entries.removeWhere((e) => e.id == id));

  void upsertSpecialDay(SpecialDay d) => updateTimetable((t) {
    t.specialDays.removeWhere((x) => x.id == d.id || dateKey(x.date) == dateKey(d.date));
    t.specialDays.add(d);
    t.specialDays.sort((a, b) => a.date.compareTo(b.date));
  });
  void removeSpecialDay(String id) =>
      updateTimetable((t) => t.specialDays.removeWhere((d) => d.id == id));

  void addChange(ClassChange c) => updateTimetable((t) => t.changes.add(c));
  void removeChange(String id) => updateTimetable((t) => t.changes.removeWhere((c) => c.id == id));

  /// Cancels (or restores) a recurring class on one date.
  void toggleCancelled(DateTime date, String entryId, {String? reason}) => updateTimetable((t) {
    final key = dateKey(date);
    final existing = t.changes.where(
      (c) => c.type == ChangeType.cancel && c.entryId == entryId && dateKey(c.date) == key,
    );
    if (existing.isNotEmpty) {
      t.changes.removeWhere((c) => existing.contains(c));
    } else {
      t.changes.add(
        ClassChange(
          date: dateOnly(date),
          type: ChangeType.cancel,
          entryId: entryId,
          reason: reason,
        ),
      );
    }
  });

  void setAttendance(String key, AttendanceStatus? status) => updateTimetable((t) {
    if (status == null) {
      t.attendance.remove(key);
    } else {
      t.attendance[key] = status;
    }
  });

  // Tasks ------------------------------------------------------------------

  void upsertTask(StudyTask task) => update((d) => _upsert(d.tasks, task, (t) => t.id));
  void removeTask(String id) => update((d) => d.tasks.removeWhere((t) => t.id == id));

  // Import / export ----------------------------------------------------------

  String exportAll() => const JsonEncoder.withIndent('  ').convert(data.toJson());

  String exportTimetable(Timetable t) {
    final json = t.toJson()..remove('attendance');
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'cadence',
      'kind': 'timetable',
      'version': AppData.schemaVersion,
      'timetable': json,
    });
  }

  /// Imports either a full backup or a single shared timetable.
  /// Returns a short description of what was imported.
  String importJson(String raw) {
    if (TtaImporter.looksLikeTta(raw)) {
      final imported = TtaImporter.parse(raw);
      for (final (i, t) in imported.indexed) {
        addTimetable(t, activate: i == 0);
      }
      final names = imported.map((t) => '“${t.name}”').join(', ');
      return imported.length == 1
          ? 'Imported $names'
          : 'Imported ${imported.length} routines: $names';
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Not a Cadence file');
    }
    if (decoded['kind'] == 'timetable') {
      final t = Timetable.fromJson(decoded['timetable'] as Map<String, dynamic>);
      final imported = data.timetables.any((x) => x.id == t.id) ? t.duplicate(t.name) : t;
      addTimetable(imported);
      return 'Added “${imported.name}”';
    }
    if (decoded['timetables'] is List) {
      final settings = data.settings;
      data = AppData.fromJson(decoded);
      // Keep device-specific preferences.
      data.settings
        ..onboarded = true
        ..launchAtStartup = settings.launchAtStartup
        ..widgetX = settings.widgetX
        ..widgetY = settings.widgetY;
      _changed();
      return 'Restored ${data.timetables.length} timetable(s) and ${data.tasks.length} task(s)';
    }
    throw const FormatException('Not a Cadence file');
  }

  void resetAll() {
    final onboarded = data.settings.onboarded;
    data = AppData()..settings.onboarded = onboarded;
    _changed();
  }

  static void _upsert<T>(List<T> list, T item, String Function(T) id) {
    final i = list.indexWhere((x) => id(x) == id(item));
    if (i == -1) {
      list.add(item);
    } else {
      list[i] = item;
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
