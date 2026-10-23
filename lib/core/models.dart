import 'package:flutter/material.dart' show ThemeMode;
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a short random identifier for new records.
String newId() => _uuid.v4().replaceAll('-', '').substring(0, 12);

/// A wall-clock time expressed as minutes after midnight.
typedef Minutes = int;

enum ClassKind {
  lecture('Lecture'),
  lab('Lab'),
  tutorial('Tutorial'),
  activity('Activity'),
  exam('Exam'),
  other('Other');

  const ClassKind(this.label);
  final String label;

  static ClassKind parse(String? value) =>
      ClassKind.values.firstWhere((k) => k.name == value, orElse: () => ClassKind.lecture);
}

/// One slot of the institution's bell schedule, e.g. "Period 3, 11:30–12:30"
/// or a break such as lunch.
class Period {
  Period({
    String? id,
    required this.label,
    required this.start,
    required this.end,
    this.isBreak = false,
  }) : id = id ?? newId();

  final String id;
  final String label;
  final Minutes start;
  final Minutes end;
  final bool isBreak;

  Period copyWith({String? label, Minutes? start, Minutes? end, bool? isBreak}) => Period(
    id: id,
    label: label ?? this.label,
    start: start ?? this.start,
    end: end ?? this.end,
    isBreak: isBreak ?? this.isBreak,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'start': start,
    'end': end,
    if (isBreak) 'isBreak': true,
  };

  factory Period.fromJson(Map<String, dynamic> j) => Period(
    id: j['id'] as String?,
    label: j['label'] as String? ?? '',
    start: j['start'] as int,
    end: j['end'] as int,
    isBreak: j['isBreak'] as bool? ?? false,
  );
}

class Teacher {
  Teacher({String? id, required this.code, required this.name, this.email, this.phone, this.notes})
    : id = id ?? newId();

  final String id;
  final String code;
  final String name;
  final String? email;
  final String? phone;
  final String? notes;

  String get displayName => name.isNotEmpty ? name : code;

  Teacher copyWith({String? code, String? name, String? email, String? phone, String? notes}) =>
      Teacher(
        id: id,
        code: code ?? this.code,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    if (email != null) 'email': email,
    if (phone != null) 'phone': phone,
    if (notes != null) 'notes': notes,
  };

  factory Teacher.fromJson(Map<String, dynamic> j) => Teacher(
    id: j['id'] as String?,
    code: j['code'] as String? ?? '',
    name: j['name'] as String? ?? '',
    email: j['email'] as String?,
    phone: j['phone'] as String?,
    notes: j['notes'] as String?,
  );
}

class Subject {
  Subject({
    String? id,
    required this.name,
    this.code = '',
    this.shortName,
    required this.color,
    this.teacherId,
    this.room,
    this.enrolled = true,
    this.reminderMinutes,
    this.notes,
  }) : id = id ?? newId();

  final String id;
  final String name;
  final String code;
  final String? shortName;

  /// ARGB colour value.
  final int color;
  final String? teacherId;

  /// Default room, used when a class doesn't specify its own.
  final String? room;

  /// Electives you don't take can be switched off to hide their classes.
  final bool enrolled;

  /// Overrides the global reminder lead time. `null` uses the default,
  /// a negative value disables reminders for this subject.
  final int? reminderMinutes;
  final String? notes;

  String get label => (shortName?.isNotEmpty ?? false) ? shortName! : name;

  Subject copyWith({
    String? name,
    String? code,
    String? shortName,
    int? color,
    String? teacherId,
    bool clearTeacher = false,
    String? room,
    bool? enrolled,
    int? reminderMinutes,
    bool clearReminder = false,
    String? notes,
  }) => Subject(
    id: id,
    name: name ?? this.name,
    code: code ?? this.code,
    shortName: shortName ?? this.shortName,
    color: color ?? this.color,
    teacherId: clearTeacher ? null : teacherId ?? this.teacherId,
    room: room ?? this.room,
    enrolled: enrolled ?? this.enrolled,
    reminderMinutes: clearReminder ? null : reminderMinutes ?? this.reminderMinutes,
    notes: notes ?? this.notes,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    if (shortName != null) 'shortName': shortName,
    'color': color,
    if (teacherId != null) 'teacherId': teacherId,
    if (room != null) 'room': room,
    if (!enrolled) 'enrolled': false,
    if (reminderMinutes != null) 'reminderMinutes': reminderMinutes,
    if (notes != null) 'notes': notes,
  };

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
    id: j['id'] as String?,
    name: j['name'] as String? ?? '',
    code: j['code'] as String? ?? '',
    shortName: j['shortName'] as String?,
    color: j['color'] as int? ?? 0xFF5B5BD6,
    teacherId: j['teacherId'] as String?,
    room: j['room'] as String?,
    enrolled: j['enrolled'] as bool? ?? true,
    reminderMinutes: j['reminderMinutes'] as int?,
    notes: j['notes'] as String?,
  );
}

/// A recurring weekly class.
class ClassEntry {
  ClassEntry({
    String? id,
    required this.weekday,
    required this.start,
    required this.end,
    this.subjectId,
    this.title,
    this.room,
    this.teacherId,
    this.kind = ClassKind.lecture,
    this.group,
    this.note,
    this.color,
    this.reminderMinutes,
    this.alarm = false,
    this.doNotDisturb = false,
  }) : id = id ?? newId();

  final String id;

  /// 1 = Monday … 7 = Sunday, matching [DateTime.weekday].
  final int weekday;
  final Minutes start;
  final Minutes end;
  final String? subjectId;

  /// Used for blocks without a subject, e.g. "Sports / Library".
  final String? title;
  final String? room;
  final String? teacherId;
  final ClassKind kind;

  /// Batch or lab group this class belongs to (e.g. "G1"). `null` means
  /// everyone attends.
  final String? group;
  final String? note;

  /// ARGB colour for entries without a subject (routines, activities).
  final int? color;

  /// Overrides the subject / global reminder lead time. `null` inherits,
  /// a negative value disables reminders for this entry.
  final int? reminderMinutes;

  /// Ring a full-screen alarm instead of showing a notification.
  final bool alarm;

  /// Silence the phone (Android Do Not Disturb) while this runs.
  final bool doNotDisturb;

  int get duration => end - start;

  /// Ends after midnight, e.g. sleep from 23:30 to 07:00.
  bool get overnight => end > 24 * 60;

  ClassEntry copyWith({
    int? weekday,
    Minutes? start,
    Minutes? end,
    String? subjectId,
    bool clearSubject = false,
    String? title,
    String? room,
    String? teacherId,
    bool clearTeacher = false,
    ClassKind? kind,
    String? group,
    bool clearGroup = false,
    String? note,
    int? color,
    int? reminderMinutes,
    bool clearReminder = false,
    bool? alarm,
    bool? doNotDisturb,
    bool keepId = true,
  }) => ClassEntry(
    id: keepId ? id : null,
    weekday: weekday ?? this.weekday,
    start: start ?? this.start,
    end: end ?? this.end,
    subjectId: clearSubject ? null : subjectId ?? this.subjectId,
    title: title ?? this.title,
    room: room ?? this.room,
    teacherId: clearTeacher ? null : teacherId ?? this.teacherId,
    kind: kind ?? this.kind,
    group: clearGroup ? null : group ?? this.group,
    note: note ?? this.note,
    color: color ?? this.color,
    reminderMinutes: clearReminder ? null : reminderMinutes ?? this.reminderMinutes,
    alarm: alarm ?? this.alarm,
    doNotDisturb: doNotDisturb ?? this.doNotDisturb,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'weekday': weekday,
    'start': start,
    'end': end,
    if (subjectId != null) 'subjectId': subjectId,
    if (title != null) 'title': title,
    if (room != null) 'room': room,
    if (teacherId != null) 'teacherId': teacherId,
    'kind': kind.name,
    if (group != null) 'group': group,
    if (note != null) 'note': note,
    if (color != null) 'color': color,
    if (reminderMinutes != null) 'reminderMinutes': reminderMinutes,
    if (alarm) 'alarm': true,
    if (doNotDisturb) 'doNotDisturb': true,
  };

  factory ClassEntry.fromJson(Map<String, dynamic> j) => ClassEntry(
    id: j['id'] as String?,
    weekday: j['weekday'] as int,
    start: j['start'] as int,
    end: j['end'] as int,
    subjectId: j['subjectId'] as String?,
    title: j['title'] as String?,
    room: j['room'] as String?,
    teacherId: j['teacherId'] as String?,
    kind: ClassKind.parse(j['kind'] as String?),
    group: j['group'] as String?,
    note: j['note'] as String?,
    color: j['color'] as int?,
    reminderMinutes: j['reminderMinutes'] as int?,
    alarm: j['alarm'] as bool? ?? false,
    doNotDisturb: j['doNotDisturb'] as bool? ?? false,
  );
}

enum SpecialDayType {
  holiday('Holiday'),
  followDay('Follows another day'),
  note('Note');

  const SpecialDayType(this.label);
  final String label;
}

/// A date that departs from the normal week: a holiday, or a working
/// Saturday that "follows Monday's timetable".
class SpecialDay {
  SpecialDay({String? id, required this.date, required this.type, this.followWeekday, this.label})
    : id = id ?? newId();

  final String id;
  final DateTime date;
  final SpecialDayType type;
  final int? followWeekday;
  final String? label;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': dateKey(date),
    'type': type.name,
    if (followWeekday != null) 'followWeekday': followWeekday,
    if (label != null) 'label': label,
  };

  factory SpecialDay.fromJson(Map<String, dynamic> j) => SpecialDay(
    id: j['id'] as String?,
    date: parseDateKey(j['date'] as String),
    type: SpecialDayType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => SpecialDayType.note,
    ),
    followWeekday: j['followWeekday'] as int?,
    label: j['label'] as String?,
  );
}

enum ChangeType { cancel, extra }

/// A one-off change on a specific date: a cancelled class or an extra one.
class ClassChange {
  ClassChange({
    String? id,
    required this.date,
    required this.type,
    this.entryId,
    this.extra,
    this.reason,
  }) : id = id ?? newId();

  final String id;
  final DateTime date;
  final ChangeType type;

  /// The cancelled recurring class.
  final String? entryId;

  /// The extra class (its `weekday` is ignored).
  final ClassEntry? extra;
  final String? reason;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': dateKey(date),
    'type': type.name,
    if (entryId != null) 'entryId': entryId,
    if (extra != null) 'extra': extra!.toJson(),
    if (reason != null) 'reason': reason,
  };

  factory ClassChange.fromJson(Map<String, dynamic> j) => ClassChange(
    id: j['id'] as String?,
    date: parseDateKey(j['date'] as String),
    type: j['type'] == 'extra' ? ChangeType.extra : ChangeType.cancel,
    entryId: j['entryId'] as String?,
    extra: j['extra'] == null ? null : ClassEntry.fromJson(j['extra'] as Map<String, dynamic>),
    reason: j['reason'] as String?,
  );
}

enum AttendanceStatus { present, absent, cancelled }

/// What a timetable is for. It changes wording and which tools are shown:
/// school timetables have subjects, teachers, groups and attendance; routines
/// are plain activities (work, gym, sleep…).
enum TimetableKind {
  school('Classes', 'class', 'classes'),
  routine('Routine', 'activity', 'activities');

  const TimetableKind(this.label, this.item, this.items);
  final String label;

  /// Lower-case noun for one entry, e.g. "class".
  final String item;
  final String items;

  String get itemTitle => item[0].toUpperCase() + item.substring(1);
  String count(int n) => '$n ${n == 1 ? item : items}';
}

class Timetable {
  Timetable({
    String? id,
    required this.name,
    this.kind = TimetableKind.school,
    this.institution,
    this.section,
    this.validFrom,
    this.validUntil,
    List<int>? workingDays,
    List<Period>? periods,
    List<Subject>? subjects,
    List<Teacher>? teachers,
    List<ClassEntry>? entries,
    List<SpecialDay>? specialDays,
    List<ClassChange>? changes,
    List<String>? groups,
    this.myGroup,
    Map<String, AttendanceStatus>? attendance,
  }) : id = id ?? newId(),
       workingDays = workingDays ?? [1, 2, 3, 4, 5],
       periods = periods ?? [],
       subjects = subjects ?? [],
       teachers = teachers ?? [],
       entries = entries ?? [],
       specialDays = specialDays ?? [],
       changes = changes ?? [],
       groups = groups ?? [],
       attendance = attendance ?? {};

  final String id;
  String name;
  TimetableKind kind;
  String? institution;
  String? section;
  DateTime? validFrom;
  DateTime? validUntil;
  List<int> workingDays;
  List<Period> periods;
  List<Subject> subjects;
  List<Teacher> teachers;
  List<ClassEntry> entries;
  List<SpecialDay> specialDays;
  List<ClassChange> changes;
  List<String> groups;
  String? myGroup;

  /// Keyed by [attendanceKey].
  Map<String, AttendanceStatus> attendance;

  Subject? subject(String? id) {
    if (id == null) return null;
    for (final s in subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  Teacher? teacher(String? id) {
    if (id == null) return null;
    for (final t in teachers) {
      if (t.id == id) return t;
    }
    return null;
  }

  String get subtitle =>
      [institution, section].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (kind != TimetableKind.school) 'kind': kind.name,
    if (institution != null) 'institution': institution,
    if (section != null) 'section': section,
    if (validFrom != null) 'validFrom': dateKey(validFrom!),
    if (validUntil != null) 'validUntil': dateKey(validUntil!),
    'workingDays': workingDays,
    'periods': periods.map((p) => p.toJson()).toList(),
    'subjects': subjects.map((s) => s.toJson()).toList(),
    'teachers': teachers.map((t) => t.toJson()).toList(),
    'entries': entries.map((e) => e.toJson()).toList(),
    'specialDays': specialDays.map((d) => d.toJson()).toList(),
    'changes': changes.map((c) => c.toJson()).toList(),
    'groups': groups,
    if (myGroup != null) 'myGroup': myGroup,
    'attendance': attendance.map((k, v) => MapEntry(k, v.name)),
  };

  factory Timetable.fromJson(Map<String, dynamic> j) => Timetable(
    id: j['id'] as String?,
    name: j['name'] as String? ?? 'Timetable',
    kind: j['kind'] == 'routine' ? TimetableKind.routine : TimetableKind.school,
    institution: j['institution'] as String?,
    section: j['section'] as String?,
    validFrom: j['validFrom'] == null ? null : parseDateKey(j['validFrom'] as String),
    validUntil: j['validUntil'] == null ? null : parseDateKey(j['validUntil'] as String),
    workingDays: (j['workingDays'] as List?)?.cast<int>(),
    periods: _list(j['periods'], Period.fromJson),
    subjects: _list(j['subjects'], Subject.fromJson),
    teachers: _list(j['teachers'], Teacher.fromJson),
    entries: _list(j['entries'], ClassEntry.fromJson),
    specialDays: _list(j['specialDays'], SpecialDay.fromJson),
    changes: _list(j['changes'], ClassChange.fromJson),
    groups: (j['groups'] as List?)?.cast<String>(),
    myGroup: j['myGroup'] as String?,
    attendance: ((j['attendance'] as Map?) ?? {}).map(
      (k, v) => MapEntry(
        k as String,
        AttendanceStatus.values.firstWhere(
          (s) => s.name == v,
          orElse: () => AttendanceStatus.present,
        ),
      ),
    ),
  );

  /// Deep copy with fresh identity, used for "Duplicate timetable".
  Timetable duplicate(String newName) {
    final copy = Timetable.fromJson(toJson());
    return Timetable.fromJson({...copy.toJson(), 'id': newId(), 'name': newName})..attendance = {};
  }
}

enum TaskType {
  assignment('Assignment'),
  exam('Exam'),
  reading('Reading'),
  project('Project'),
  other('Other');

  const TaskType(this.label);
  final String label;
}

class StudyTask {
  StudyTask({
    String? id,
    required this.title,
    this.type = TaskType.assignment,
    this.subjectId,
    this.due,
    this.notes,
    this.done = false,
    this.remindBefore = 24 * 60,
    DateTime? createdAt,
  }) : id = id ?? newId(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final TaskType type;
  final String? subjectId;
  final DateTime? due;
  final String? notes;
  final bool done;

  /// Minutes before [due] to send a reminder; negative disables it.
  final int remindBefore;
  final DateTime createdAt;

  StudyTask copyWith({
    String? title,
    TaskType? type,
    String? subjectId,
    bool clearSubject = false,
    DateTime? due,
    bool clearDue = false,
    String? notes,
    bool? done,
    int? remindBefore,
  }) => StudyTask(
    id: id,
    title: title ?? this.title,
    type: type ?? this.type,
    subjectId: clearSubject ? null : subjectId ?? this.subjectId,
    due: clearDue ? null : due ?? this.due,
    notes: notes ?? this.notes,
    done: done ?? this.done,
    remindBefore: remindBefore ?? this.remindBefore,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type.name,
    if (subjectId != null) 'subjectId': subjectId,
    if (due != null) 'due': due!.toIso8601String(),
    if (notes != null) 'notes': notes,
    if (done) 'done': true,
    'remindBefore': remindBefore,
    'createdAt': createdAt.toIso8601String(),
  };

  factory StudyTask.fromJson(Map<String, dynamic> j) => StudyTask(
    id: j['id'] as String?,
    title: j['title'] as String? ?? '',
    type: TaskType.values.firstWhere((t) => t.name == j['type'], orElse: () => TaskType.other),
    subjectId: j['subjectId'] as String?,
    due: j['due'] == null ? null : DateTime.parse(j['due'] as String),
    notes: j['notes'] as String?,
    done: j['done'] as bool? ?? false,
    remindBefore: j['remindBefore'] as int? ?? 24 * 60,
    createdAt: j['createdAt'] == null ? null : DateTime.tryParse(j['createdAt'] as String),
  );
}

enum WidgetLayer { normal, onTop, onDesktop }

class Settings {
  Settings({
    this.themeMode = ThemeMode.system,
    this.accent,
    this.useDynamicColor = true,
    this.use24h,
    this.showWeekends = false,
    this.remindersEnabled = true,
    this.reminderMinutes = 10,
    this.notifyAtStart = false,
    this.dailySummary = true,
    this.dailySummaryAt = 7 * 60 + 30,
    this.morningAlarm = false,
    this.morningAlarmLead = 60,
    this.taskReminders = true,
    this.attendanceTarget = 75,
    this.launchAtStartup = false,
    this.startHidden = true,
    this.closeToTray = true,
    this.widgetOnStartup = true,
    this.widgetLayer = WidgetLayer.onTop,
    this.widgetOpacity = 1.0,
    this.widgetX,
    this.widgetY,
    this.widgetWidth = 340,
    this.widgetHeight = 460,
    this.onboarded = false,
  });

  ThemeMode themeMode;

  /// Brand colour override; `null` keeps the default.
  int? accent;
  bool useDynamicColor;

  /// `null` follows the system preference.
  bool? use24h;
  bool showWeekends;

  bool remindersEnabled;
  int reminderMinutes;
  bool notifyAtStart;
  bool dailySummary;
  Minutes dailySummaryAt;
  bool morningAlarm;
  int morningAlarmLead;
  bool taskReminders;

  int attendanceTarget;

  bool launchAtStartup;
  bool startHidden;
  bool closeToTray;
  bool widgetOnStartup;
  WidgetLayer widgetLayer;
  double widgetOpacity;
  double? widgetX;
  double? widgetY;
  double widgetWidth;
  double widgetHeight;

  bool onboarded;

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    if (accent != null) 'accent': accent,
    'useDynamicColor': useDynamicColor,
    if (use24h != null) 'use24h': use24h,
    'showWeekends': showWeekends,
    'remindersEnabled': remindersEnabled,
    'reminderMinutes': reminderMinutes,
    'notifyAtStart': notifyAtStart,
    'dailySummary': dailySummary,
    'dailySummaryAt': dailySummaryAt,
    'morningAlarm': morningAlarm,
    'morningAlarmLead': morningAlarmLead,
    'taskReminders': taskReminders,
    'attendanceTarget': attendanceTarget,
    'launchAtStartup': launchAtStartup,
    'startHidden': startHidden,
    'closeToTray': closeToTray,
    'widgetOnStartup': widgetOnStartup,
    'widgetLayer': widgetLayer.name,
    'widgetOpacity': widgetOpacity,
    if (widgetX != null) 'widgetX': widgetX,
    if (widgetY != null) 'widgetY': widgetY,
    'widgetWidth': widgetWidth,
    'widgetHeight': widgetHeight,
    'onboarded': onboarded,
  };

  factory Settings.fromJson(Map<String, dynamic> j) {
    final d = Settings();
    return Settings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == j['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      accent: j['accent'] as int?,
      useDynamicColor: j['useDynamicColor'] as bool? ?? d.useDynamicColor,
      use24h: j['use24h'] as bool?,
      showWeekends: j['showWeekends'] as bool? ?? d.showWeekends,
      remindersEnabled: j['remindersEnabled'] as bool? ?? d.remindersEnabled,
      reminderMinutes: j['reminderMinutes'] as int? ?? d.reminderMinutes,
      notifyAtStart: j['notifyAtStart'] as bool? ?? d.notifyAtStart,
      dailySummary: j['dailySummary'] as bool? ?? d.dailySummary,
      dailySummaryAt: j['dailySummaryAt'] as int? ?? d.dailySummaryAt,
      morningAlarm: j['morningAlarm'] as bool? ?? d.morningAlarm,
      morningAlarmLead: j['morningAlarmLead'] as int? ?? d.morningAlarmLead,
      taskReminders: j['taskReminders'] as bool? ?? d.taskReminders,
      attendanceTarget: j['attendanceTarget'] as int? ?? d.attendanceTarget,
      launchAtStartup: j['launchAtStartup'] as bool? ?? d.launchAtStartup,
      startHidden: j['startHidden'] as bool? ?? d.startHidden,
      closeToTray: j['closeToTray'] as bool? ?? d.closeToTray,
      widgetOnStartup: j['widgetOnStartup'] as bool? ?? d.widgetOnStartup,
      widgetLayer: WidgetLayer.values.firstWhere(
        (l) => l.name == j['widgetLayer'],
        orElse: () => d.widgetLayer,
      ),
      widgetOpacity: (j['widgetOpacity'] as num?)?.toDouble() ?? d.widgetOpacity,
      widgetX: (j['widgetX'] as num?)?.toDouble(),
      widgetY: (j['widgetY'] as num?)?.toDouble(),
      widgetWidth: (j['widgetWidth'] as num?)?.toDouble() ?? d.widgetWidth,
      widgetHeight: (j['widgetHeight'] as num?)?.toDouble() ?? d.widgetHeight,
      onboarded: j['onboarded'] as bool? ?? d.onboarded,
    );
  }
}

class AppData {
  AppData({
    List<Timetable>? timetables,
    this.activeTimetableId,
    List<StudyTask>? tasks,
    Settings? settings,
  }) : timetables = timetables ?? [],
       tasks = tasks ?? [],
       settings = settings ?? Settings();

  static const schemaVersion = 1;

  List<Timetable> timetables;
  String? activeTimetableId;
  List<StudyTask> tasks;
  Settings settings;

  Timetable? get active {
    for (final t in timetables) {
      if (t.id == activeTimetableId) return t;
    }
    return timetables.isEmpty ? null : timetables.first;
  }

  Map<String, dynamic> toJson() => {
    'app': 'cadence',
    'version': schemaVersion,
    'timetables': timetables.map((t) => t.toJson()).toList(),
    if (activeTimetableId != null) 'activeTimetableId': activeTimetableId,
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'settings': settings.toJson(),
  };

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
    timetables: _list(j['timetables'], Timetable.fromJson),
    activeTimetableId: j['activeTimetableId'] as String?,
    tasks: _list(j['tasks'], StudyTask.fromJson),
    settings: j['settings'] == null
        ? null
        : Settings.fromJson(j['settings'] as Map<String, dynamic>),
  );
}

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) => raw is List
    ? raw.whereType<Map>().map((m) => parse(m.cast<String, dynamic>())).toList()
    : <T>[];

String _two(int v) => v.toString().padLeft(2, '0');

/// `yyyy-MM-dd` key for a calendar date.
String dateKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

DateTime parseDateKey(String key) {
  final parts = key.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

String attendanceKey(DateTime date, String entryId) => '${dateKey(date)}|$entryId';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
