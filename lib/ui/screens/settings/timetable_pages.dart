import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/formatting.dart';
import '../../../core/models.dart';
import '../../../core/sample_data.dart';
import '../../app_scope.dart';
import '../../editors/misc_editors.dart';
import '../../editors/subject_editor.dart';
import '../../editors/teacher_editor.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'data_actions.dart';

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.children, this.fab, this.subtitle});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? fab;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    floatingActionButton: fab,
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      children: [
        if (subtitle != null)
          PageBody(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                subtitle!,
                style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
          ),
        for (final c in children) PageBody(child: c),
      ],
    ),
  );
}

class TimetablesPage extends StatelessWidget {
  const TimetablesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final active = store.timetable;
    return _Page(
      title: 'Timetables',
      subtitle: 'Keep one per semester, or one for each section you teach. Only the active one sends reminders.',
      fab: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Timetable'),
      ),
      children: [
        for (final t in store.data.timetables)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                leading: Icon(
                  t.id == active?.id
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: t.id == active?.id ? context.colors.primary : null,
                ),
                title: Text(t.name, style: context.text.titleSmall),
                subtitle: Text(
                  [
                    if (t.subtitle.isNotEmpty) t.subtitle,
                    t.kind == TimetableKind.school
                        ? '${t.subjects.length} subjects · ${t.kind.count(t.entries.length)}'
                        : 'Routine · ${t.kind.count(t.entries.length)}',
                  ].join('\n'),
                ),
                isThreeLine: t.subtitle.isNotEmpty,
                onTap: () => store.setActive(t.id),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'edit':
                        showEditor(context, TimetableDetailsEditor(timetable: t));
                      case 'duplicate':
                        store.addTimetable(t.duplicate('${t.name} (copy)'), activate: false);
                      case 'delete':
                        if (await confirm(
                          context,
                          title: 'Delete “${t.name}”?',
                          message: 'Everything in it will be removed from this device.',
                        )) {
                          store.removeTimetable(t.id);
                        }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit details')),
                    PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _add(BuildContext context) => showModalBottomSheet(
    useRootNavigator: true,
    context: context,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.work_outline_rounded),
            title: const Text('New daily routine'),
            subtitle: const Text('Work, gym, study blocks, sleep — any day plan'),
            onTap: () {
              Navigator.pop(sheet);
              showEditor(
                context,
                TimetableDetailsEditor(
                  timetable: Timetable(
                    name: 'My routine',
                    kind: TimetableKind.routine,
                    workingDays: [1, 2, 3, 4, 5, 6, 7],
                  ),
                  isNew: true,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_calendar_outlined),
            title: const Text('New class timetable'),
            subtitle: const Text('With a typical bell schedule you can adjust'),
            onTap: () {
              Navigator.pop(sheet);
              showEditor(
                context,
                TimetableDetailsEditor(
                  timetable: Timetable(name: 'My timetable', periods: defaultPeriods()),
                  isNew: true,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_open_outlined),
            title: const Text('Import a file'),
            subtitle: const Text('Shared by a classmate, a backup, or a .tta file from TimeTable'),
            onTap: () {
              Navigator.pop(sheet);
              DataActions.importFile(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('Example class timetable'),
            subtitle: const Text('B.Tech CSE, Semester VI'),
            onTap: () {
              Navigator.pop(sheet);
              context.readStore.loadSample();
            },
          ),
          ListTile(
            leading: const Icon(Icons.wb_twilight_rounded),
            title: const Text('Example routine'),
            subtitle: const Text('A typical working week'),
            onTap: () {
              Navigator.pop(sheet);
              context.readStore.loadSample(routine: true);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class SubjectsPage extends StatelessWidget {
  const SubjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = context.store.timetable!;
    final counts = <String, int>{};
    for (final e in tt.entries) {
      if (e.subjectId != null) counts[e.subjectId!] = (counts[e.subjectId!] ?? 0) + 1;
    }
    return _Page(
      title: 'Subjects',
      subtitle: 'Switch off electives you don’t take — their classes disappear from your views, widgets and reminders.',
      fab: FloatingActionButton.extended(
        onPressed: () => showEditor(context, const SubjectEditor()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Subject'),
      ),
      children: [
        if (tt.subjects.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No subjects yet')),
          ),
        for (final s in tt.subjects)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                leading: CircleAvatar(
                  backgroundColor: context.tone(s.color).container,
                  child: Text(
                    (s.shortName ?? s.name).characters.first.toUpperCase(),
                    style: TextStyle(
                      color: context.tone(s.color).accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(s.name, style: context.text.titleSmall),
                subtitle: Text(
                  [
                    if (s.code.isNotEmpty) s.code,
                    if (tt.teacher(s.teacherId) != null) tt.teacher(s.teacherId)!.displayName,
                    '${counts[s.id] ?? 0} classes/week',
                  ].join(' · '),
                ),
                trailing: Switch(
                  value: s.enrolled,
                  onChanged: (v) => context.readStore.upsertSubject(s.copyWith(enrolled: v)),
                ),
                onTap: () => showEditor(context, SubjectEditor(subject: s)),
              ),
            ),
          ),
      ],
    );
  }
}

class TeachersPage extends StatelessWidget {
  const TeachersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = context.store.timetable!;
    return _Page(
      title: 'Teachers',
      fab: FloatingActionButton.extended(
        onPressed: () => showEditor(context, const TeacherEditor()),
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Teacher'),
      ),
      children: [
        if (tt.teachers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No teachers yet')),
          ),
        for (final t in tt.teachers)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: context.colors.secondaryContainer,
                  child: Text(
                    (t.code.isNotEmpty ? t.code : t.name).characters.take(2).toString(),
                    style: TextStyle(
                      color: context.colors.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                title: Text(t.displayName, style: context.text.titleSmall),
                subtitle: Text(
                  [...tt.subjects.where((s) => s.teacherId == t.id).map((s) => s.label)]
                      .join(', ')
                      .ifEmpty(t.email ?? 'No subjects'),
                ),
                onTap: () => showEditor(context, TeacherEditor(teacher: t)),
              ),
            ),
          ),
      ],
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class BellSchedulePage extends StatelessWidget {
  const BellSchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = context.store.timetable!;
    final fmt = context.timeFormat;
    return _Page(
      title: 'Bell schedule',
      subtitle: 'Periods make adding classes a single tap. Breaks show up as gaps in your day.',
      fab: FloatingActionButton.extended(
        onPressed: () => showEditor(context, const PeriodEditor()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Period'),
      ),
      children: [
        for (final p in tt.periods)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              color: p.isBreak
                  ? context.colors.surfaceContainerHighest.withValues(alpha: 0.5)
                  : null,
              child: ListTile(
                leading: Icon(p.isBreak ? Icons.restaurant_outlined : Icons.schedule_rounded),
                title: Text(p.label, style: context.text.titleSmall),
                subtitle: Text(
                  '${fmt.range(p.start, p.end)} · ${humanDuration(Duration(minutes: p.end - p.start))}',
                ),
                onTap: () => showEditor(context, PeriodEditor(period: p)),
              ),
            ),
          ),
      ],
    );
  }
}

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    context.readStore.updateTimetable((t) {
      if (!t.groups.contains(name)) t.groups.add(name);
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final tt = context.store.timetable!;
    return _Page(
      title: 'Groups & batches',
      subtitle: 'Labs are often split into groups (G1, G2…). Pick yours and Cadence only shows the classes meant for you.',
      children: [
        const SectionHeader('My group'),
        RadioGroup<String?>(
          groupValue: tt.myGroup,
          onChanged: (v) => context.readStore.updateTimetable((t) => t.myGroup = v),
          child: Card(
            child: Column(
              children: [
                const RadioListTile<String?>(
                  value: null,
                  title: Text('Show every group'),
                  subtitle: Text('Useful for teachers and class reps'),
                ),
                for (final g in tt.groups)
                  RadioListTile<String?>(
                    value: g,
                    title: Text('Group $g'),
                    secondary: IconButton(
                      tooltip: 'Remove group',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => context.readStore.updateTimetable((t) {
                        t.groups.remove(g);
                        if (t.myGroup == g) t.myGroup = null;
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SectionHeader('Add a group'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(hintText: 'e.g. G3 or Batch B'),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(onPressed: _add, child: const Text('Add')),
          ],
        ),
      ],
    );
  }
}

class SpecialDaysPage extends StatelessWidget {
  const SpecialDaysPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = context.store.timetable!;
    final today = dateOnly(DateTime.now());
    final upcoming = tt.specialDays.where((d) => !d.date.isBefore(today)).toList();
    final past = tt.specialDays.where((d) => d.date.isBefore(today)).toList().reversed.toList();

    Widget tile(SpecialDay d) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: Icon(switch (d.type) {
            SpecialDayType.holiday => Icons.beach_access_outlined,
            SpecialDayType.followDay => Icons.swap_horiz_rounded,
            SpecialDayType.note => Icons.sticky_note_2_outlined,
          }, color: context.colors.tertiary),
          title: Text(DateFormat('EEE, d MMM y').format(d.date), style: context.text.titleSmall),
          subtitle: Text(switch (d.type) {
            SpecialDayType.holiday => 'Holiday${d.label != null ? ' · ${d.label}' : ''}',
            SpecialDayType.followDay =>
              'Follows ${weekdayName(d.followWeekday ?? 1)}${d.label != null ? ' · ${d.label}' : ''}',
            SpecialDayType.note => d.label ?? 'Note',
          }),
          onTap: () => showEditor(context, SpecialDayEditor(day: d)),
        ),
      ),
    );

    return _Page(
      title: 'Holidays & special days',
      subtitle: 'Mark holidays, or working Saturdays that follow another weekday’s timetable.',
      fab: FloatingActionButton.extended(
        onPressed: () => showEditor(context, const SpecialDayEditor()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Day'),
      ),
      children: [
        if (tt.specialDays.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No special days yet')),
          ),
        if (upcoming.isNotEmpty) const SectionHeader('Upcoming'),
        ...upcoming.map(tile),
        if (past.isNotEmpty) const SectionHeader('Past'),
        ...past.map(tile),
      ],
    );
  }
}
