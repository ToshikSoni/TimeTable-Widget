import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/formatting.dart';
import '../../core/models.dart';
import '../app_scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'editor_scaffold.dart';
import 'subject_editor.dart';

/// Creates or edits a weekly class. With [date] set it creates a one-off
/// extra class on that date instead.
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
  bool _initialised = false;

  bool get _isNew => widget.entry == null;
  bool get _isExtra => widget.date != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final tt = context.readStore.timetable!;
    final e = widget.entry;
    _subjectId =
        e?.subjectId ?? (tt.subjects.isNotEmpty && e == null ? tt.subjects.first.id : null);
    _teacherId = e?.teacherId;
    _group = e?.group;
    _kind = e?.kind ?? ClassKind.lecture;
    _days = {e?.weekday ?? widget.weekday ?? widget.date?.weekday ?? DateTime.now().weekday};
    final periods = tt.periods.where((p) => !p.isBreak).toList();
    final firstPeriod = periods.isEmpty ? null : periods.first;
    _start = e?.start ?? widget.start ?? firstPeriod?.start ?? 9 * 60;
    final matching = periods.where((p) => p.start == _start);
    _end = e?.end ?? (matching.isNotEmpty ? matching.first.end : _start + 60);
  }

  @override
  void dispose() {
    _title.dispose();
    _room.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool start) async {
    final current = start ? _start : _end;
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
        _end = m;
      }
    });
  }

  void _save() {
    if (_end <= _start) {
      context.toast('The class must end after it starts');
      return;
    }
    if (_subjectId == null && _title.text.trim().isEmpty) {
      context.toast('Pick a subject or enter a title');
      return;
    }
    final store = context.readStore;
    String? clean(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    ClassEntry build(int day, {String? id}) => ClassEntry(
      id: id,
      weekday: day,
      start: _start,
      end: _end,
      subjectId: _subjectId,
      title: _subjectId == null ? clean(_title) : null,
      room: clean(_room),
      teacherId: _teacherId,
      kind: _kind,
      group: _group,
      note: clean(_note),
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
    final ok = await confirm(
      context,
      title: 'Delete this class?',
      message: 'It will be removed from every week.',
    );
    if (!ok || !mounted) return;
    context.readStore.removeEntry(widget.entry!.id);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final tt = context.store.timetable!;
    final fmt = context.timeFormat;
    final periods = tt.periods.where((p) => !p.isBreak).toList();
    final subject = tt.subject(_subjectId);
    final inheritedTeacher = tt.teacher(subject?.teacherId);

    return EditorScaffold(
      title: _isExtra
          ? 'Extra class · ${DateFormat('d MMM').format(widget.date!)}'
          : _isNew
          ? 'New class'
          : 'Edit class',
      onSave: _save,
      onDelete: _isNew || _isExtra ? null : _delete,
      children: [
        const FieldLabel('Subject'),
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
              label: const Text('Other'),
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
        if (_subjectId == null)
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. Sports / Library',
            ),
          ),
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
                label: 'Ends',
                value: fmt.minutes(_end),
                onTap: () => _pickTime(false),
              ),
            ),
          ],
        ),
        TextField(
          controller: _room,
          decoration: InputDecoration(
            labelText: 'Room',
            hintText: subject?.room ?? 'e.g. NCR-01',
            prefixIcon: const Icon(Icons.place_outlined),
          ),
        ),
        DropdownButtonFormField<String?>(
          initialValue: _teacherId,
          decoration: const InputDecoration(
            labelText: 'Teacher',
            prefixIcon: Icon(Icons.person_outline_rounded),
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
      ],
    );
  }
}
