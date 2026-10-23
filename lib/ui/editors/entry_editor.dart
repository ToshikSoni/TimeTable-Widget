import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/formatting.dart';
import '../../core/models.dart';
import '../../core/palette.dart';
import '../../services/dnd.dart';
import '../app_scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'editor_scaffold.dart';
import 'subject_editor.dart';

/// Creates or edits a weekly class (or routine activity). With [date] set it
/// creates a one-off extra entry on that date instead.
class EntryEditor extends StatefulWidget {
  const EntryEditor({super.key, this.entry, this.weekday, this.start, this.date});

  final ClassEntry? entry;
  final int? weekday;
  final Minutes? start;
  final DateTime? date;

  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  late final _title = TextEditingController(text: widget.entry?.title);
  late final _room = TextEditingController(text: widget.entry?.room);
  late final _note = TextEditingController(text: widget.entry?.note);
  String? _subjectId;
  String? _teacherId;
  String? _group;
  late ClassKind _kind;
  late Set<int> _days;
  late Minutes _start;
  late Minutes _end;
  int? _color;
  int? _reminder;
  bool _alarm = false;
  bool _dnd = false;
  bool _initialised = false;

  bool get _isNew => widget.entry == null;
  bool get _isExtra => widget.date != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final tt = context.readStore.timetable!;
    final routine = tt.kind == TimetableKind.routine;
    final e = widget.entry;
    _subjectId =
        e?.subjectId ??
        (!routine && tt.subjects.isNotEmpty && e == null ? tt.subjects.first.id : null);
    _teacherId = e?.teacherId;
    _group = e?.group;
    _kind = e?.kind ?? (routine ? ClassKind.activity : ClassKind.lecture);
    _days = {e?.weekday ?? widget.weekday ?? widget.date?.weekday ?? DateTime.now().weekday};
    final periods = tt.periods.where((p) => !p.isBreak).toList();
    final firstPeriod = periods.isEmpty ? null : periods.first;
    _start = e?.start ?? widget.start ?? firstPeriod?.start ?? 9 * 60;
    final matching = periods.where((p) => p.start == _start);
    _end = e?.end ?? (matching.isNotEmpty ? matching.first.end : _start + 60);
    _color = e?.color ?? (routine && e == null ? _unusedColor(tt) : null);
    _reminder = e?.reminderMinutes;
    _alarm = e?.alarm ?? false;
    _dnd = e?.doNotDisturb ?? false;
  }

  int _unusedColor(Timetable tt) {
    final used = {for (final e in tt.entries) e.color};
    return kRoutinePalette.firstWhere(
      (c) => !used.contains(c),
      orElse: () => kRoutinePalette.first,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _room.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool start) async {
    final current = (start ? _start : _end) % (24 * 60);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: context.use24h),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      final m = picked.hour * 60 + picked.minute;
      if (start) {
        final length = _end - _start;
        _start = m;
        _end = m + (length > 0 ? length : 60);
      } else {
        // An end time at or before the start means it finishes the next day,
        // e.g. sleep from 23:30 to 07:00.
        _end = m <= _start ? m + 24 * 60 : m;
      }
    });
  }

  void _save() {
    final routine = context.readStore.timetable!.kind == TimetableKind.routine;
    if (_end <= _start) {
      context.toast('It must end after it starts');
      return;
    }
    if (_subjectId == null && _title.text.trim().isEmpty) {
      context.toast(routine ? 'Give it a name' : 'Pick a subject or enter a title');
      return;
    }
    final store = context.readStore;
    String? clean(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final subjectId = _subjectId;
    ClassEntry build(int day, {String? id}) => ClassEntry(
      id: id,
      weekday: day,
      start: _start,
      end: _end,
      subjectId: subjectId,
      title: subjectId == null ? clean(_title) : null,
      room: clean(_room),
      teacherId: _teacherId,
      kind: _kind,
      group: _group,
      note: clean(_note),
      color: subjectId == null ? _color : null,
      reminderMinutes: _reminder,
      alarm: _alarm,
      doNotDisturb: _dnd,
    );

    if (_isExtra) {
      store.addChange(
        ClassChange(
          date: dateOnly(widget.date!),
          type: ChangeType.extra,
          extra: build(widget.date!.weekday),
        ),
      );
    } else if (_isNew) {
      for (final d in _days) {
        store.upsertEntry(build(d));
      }
    } else {
      store.upsertEntry(build(_days.first, id: widget.entry!.id));
    }
    Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final noun = context.readStore.timetable!.kind.item;
    final ok = await confirm(
      context,
      title: 'Delete this $noun?',
      message: 'It will be removed from every week.',
    );
    if (!ok || !mounted) return;
    context.readStore.removeEntry(widget.entry!.id);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final tt = context.store.timetable!;
    final routine = tt.kind == TimetableKind.routine;
    final noun = tt.kind.item;
    final fmt = context.timeFormat;
    final periods = tt.periods.where((p) => !p.isBreak).toList();
    final subject = tt.subject(_subjectId);
    final inheritedTeacher = tt.teacher(subject?.teacherId);
    final defaultLead = subject?.reminderMinutes ?? context.settings.reminderMinutes;

    return EditorScaffold(
      title: _isExtra
          ? 'Extra $noun · ${DateFormat('d MMM').format(widget.date!)}'
          : _isNew
          ? 'New $noun'
          : 'Edit $noun',
      onSave: _save,
      onDelete: _isNew || _isExtra ? null : _delete,
      children: [
        if (!routine || tt.subjects.isNotEmpty) ...[
          FieldLabel(routine ? 'Category' : 'Subject'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in tt.subjects)
                ChoiceChip(
                  avatar: ColorDot(context.tone(s.color).accent),
                  label: Text(s.label),
                  selected: _subjectId == s.id,
                  onSelected: (_) => setState(() => _subjectId = s.id),
                ),
              ChoiceChip(
                avatar: const Icon(Icons.edit_outlined, size: 16),
                label: Text(routine ? 'None' : 'Other'),
                selected: _subjectId == null,
                onSelected: (_) => setState(() => _subjectId = null),
              ),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New subject'),
                onPressed: () async {
                  final created = await showEditor<Subject>(context, const SubjectEditor());
                  if (created != null) setState(() => _subjectId = created.id);
                },
              ),
            ],
          ),
        ],
        if (_subjectId == null)
          TextField(
            controller: _title,
            autofocus: routine && _isNew,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: routine ? 'What is it?' : 'Title',
              hintText: routine ? 'e.g. Gym, Deep work, Commute' : 'e.g. Sports / Library',
            ),
          ),
        if (_subjectId == null) ...[
          const FieldLabel('Colour'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in kRoutinePalette)
                InkResponse(
                  onTap: () => setState(() => _color = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: context.tone(c).accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == c ? context.colors.onSurface : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: _color == c
                        ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ],
        ...[
          const FieldLabel('Type'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<ClassKind>(
              showSelectedIcon: false,
              segments: [
                for (final k in ClassKind.values) ButtonSegment(value: k, label: Text(k.label)),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
          ),
        ],
        if (!_isExtra) ...[
          FieldLabel(_isNew ? 'Days (pick several to repeat)' : 'Day'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  showCheckmark: false,
                  label: Text(weekdayShort(d)),
                  selected: _days.contains(d),
                  onSelected: (on) => setState(() {
                    if (_isNew) {
                      if (on) {
                        _days.add(d);
                      } else if (_days.length > 1) {
                        _days.remove(d);
                      }
                    } else {
                      _days = {d};
                    }
                  }),
                ),
              if (_isNew)
                ActionChip(
                  label: const Text('Every day'),
                  onPressed: () => setState(() => _days = {1, 2, 3, 4, 5, 6, 7}),
                ),
              if (_isNew)
                ActionChip(
                  label: const Text('Weekdays'),
                  onPressed: () => setState(() => _days = {1, 2, 3, 4, 5}),
                ),
            ],
          ),
        ],
        if (periods.isNotEmpty) ...[
          const FieldLabel('Period'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in periods)
                ChoiceChip(
                  label: Text('${p.label.replaceAll('Period ', 'P')} · ${fmt.minutes(p.start)}'),
                  selected: _start <= p.start && _end >= p.end,
                  onSelected: (_) => setState(() {
                    // Tapping a later period extends a block (e.g. 2-hour labs).
                    if (p.start == _end) {
                      _end = p.end;
                    } else {
                      _start = p.start;
                      _end = p.end;
                    }
                  }),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Tip: tap the next period to make a double-length block.',
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
        ],
        Row(
          children: [
            Expanded(
              child: PickerField(
                label: 'Starts',
                value: fmt.minutes(_start),
                icon: Icons.schedule_rounded,
                onTap: () => _pickTime(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PickerField(
                label: _end > 24 * 60 ? 'Ends (next day)' : 'Ends',
                value: fmt.minutes(_end),
                onTap: () => _pickTime(false),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            humanDuration(Duration(minutes: _end - _start)),
            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
        TextField(
          controller: _room,
          decoration: InputDecoration(
            labelText: routine ? 'Place' : 'Room',
            hintText: subject?.room ?? (routine ? 'Optional' : 'e.g. NCR-01'),
            prefixIcon: const Icon(Icons.place_outlined),
          ),
        ),
        if (!routine || tt.teachers.isNotEmpty)
          DropdownButtonFormField<String?>(
            initialValue: _teacherId,
            decoration: InputDecoration(
              labelText: routine ? 'With' : 'Teacher',
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(
                  inheritedTeacher == null
                      ? 'None'
                      : 'Subject default (${inheritedTeacher.displayName})',
                ),
              ),
              for (final t in tt.teachers)
                DropdownMenuItem(
                  value: t.id,
                  child: Text(t.code.isEmpty ? t.name : '${t.name} (${t.code})'),
                ),
            ],
            onChanged: (v) => setState(() => _teacherId = v),
          ),
        if (tt.groups.isNotEmpty)
          DropdownButtonFormField<String?>(
            initialValue: _group,
            decoration: const InputDecoration(
              labelText: 'Group / batch',
              prefixIcon: Icon(Icons.groups_2_outlined),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Everyone')),
              for (final g in tt.groups) DropdownMenuItem(value: g, child: Text('Group $g')),
            ],
            onChanged: (v) => setState(() => _group = v),
          ),
        TextField(
          controller: _note,
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Note',
            prefixIcon: Icon(Icons.notes_rounded),
          ),
        ),
        const FieldLabel('Alerts'),
        DropdownButtonFormField<int?>(
          initialValue: _reminder,
          decoration: const InputDecoration(
            labelText: 'Remind me',
            prefixIcon: Icon(Icons.notifications_outlined),
          ),
          items: [
            DropdownMenuItem(value: null, child: Text('Default (${leadTimeLabel(defaultLead)})')),
            const DropdownMenuItem(value: -1, child: Text('No reminder')),
            for (final m in const [0, 5, 10, 15, 30, 60])
              DropdownMenuItem(value: m, child: Text(leadTimeLabel(m))),
          ],
          onChanged: (v) => setState(() => _reminder = v),
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          secondary: const Icon(Icons.alarm_rounded),
          title: const Text('Ring as an alarm'),
          subtitle: const Text('Full-screen with sound until you dismiss it'),
          value: _alarm,
          onChanged: (v) => setState(() => _alarm = v),
        ),
        if (DndService.supported)
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            secondary: const Icon(Icons.do_not_disturb_on_outlined),
            title: const Text('Do not disturb'),
            subtitle: const Text('Silence the phone while this is on'),
            value: _dnd,
            onChanged: (v) async {
              if (v && !await DndService.hasAccess()) {
                if (!context.mounted) return;
                final go = await confirm(
                  context,
                  title: 'Allow Do Not Disturb access',
                  message:
                      'Android asks you to allow Cadence to change Do Not Disturb. '
                      'Find Cadence in the list and switch it on, then come back.',
                  action: 'Open settings',
                  destructive: false,
                );
                if (go) await DndService.requestAccess();
              }
              setState(() => _dnd = v);
            },
          ),
      ],
    );
  }
}
