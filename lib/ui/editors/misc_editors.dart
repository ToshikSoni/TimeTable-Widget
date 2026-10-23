import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/formatting.dart';
import '../../core/models.dart';
import '../app_scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'editor_scaffold.dart';

/// Holidays and "this Saturday follows Monday" days.
class SpecialDayEditor extends StatefulWidget {
  const SpecialDayEditor({super.key, this.day, this.date});
  final SpecialDay? day;
  final DateTime? date;

  @override
  State<SpecialDayEditor> createState() => _SpecialDayEditorState();
}

class _SpecialDayEditorState extends State<SpecialDayEditor> {
  late DateTime _date = widget.day?.date ?? widget.date ?? dateOnly(DateTime.now());
  late SpecialDayType _type = widget.day?.type ?? SpecialDayType.holiday;
  late int _follow = widget.day?.followWeekday ?? DateTime.monday;
  late final _label = TextEditingController(text: widget.day?.label);

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _save() {
    context.readStore.upsertSpecialDay(
      SpecialDay(
        id: widget.day?.id,
        date: _date,
        type: _type,
        followWeekday: _type == SpecialDayType.followDay ? _follow : null,
        label: _label.text.trim().isEmpty ? null : _label.text.trim(),
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => EditorScaffold(
    title: widget.day == null ? 'Special day' : 'Edit special day',
    onSave: _save,
    onDelete: widget.day == null
        ? null
        : () {
            context.readStore.removeSpecialDay(widget.day!.id);
            Navigator.pop(context, true);
          },
    children: [
      PickerField(
        label: 'Date',
        icon: Icons.event_outlined,
        value: DateFormat('EEEE, d MMMM y').format(_date),
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: _date,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (d != null) setState(() => _date = d);
        },
      ),
      const FieldLabel('What happens on this day?'),
      RadioGroup<SpecialDayType>(
        groupValue: _type,
        onChanged: (v) => setState(() => _type = v!),
        child: const Column(
          children: [
            RadioListTile(
              value: SpecialDayType.holiday,
              title: Text('Holiday'),
              subtitle: Text('No classes, no reminders'),
            ),
            RadioListTile(
              value: SpecialDayType.followDay,
              title: Text('Follows another day’s timetable'),
              subtitle: Text('e.g. a working Saturday with Monday’s classes'),
            ),
            RadioListTile(
              value: SpecialDayType.note,
              title: Text('Just a note'),
              subtitle: Text('Classes as usual, with a banner'),
            ),
          ],
        ),
      ),
      if (_type == SpecialDayType.followDay)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var d = 1; d <= 7; d++)
              ChoiceChip(
                label: Text(weekdayName(d)),
                selected: _follow == d,
                onSelected: (_) => setState(() => _follow = d),
              ),
          ],
        ),
      TextField(
        controller: _label,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Label',
          hintText: _type == SpecialDayType.holiday ? 'e.g. Diwali' : 'e.g. Working Saturday',
          prefixIcon: const Icon(Icons.label_outline_rounded),
        ),
      ),
    ],
  );
}

class PeriodEditor extends StatefulWidget {
  const PeriodEditor({super.key, this.period});
  final Period? period;

  @override
  State<PeriodEditor> createState() => _PeriodEditorState();
}

class _PeriodEditorState extends State<PeriodEditor> {
  late final _label = TextEditingController(text: widget.period?.label);
  late Minutes _start = widget.period?.start ?? 9 * 60;
  late Minutes _end = widget.period?.end ?? 10 * 60;
  late bool _isBreak = widget.period?.isBreak ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.period == null && _label.text.isEmpty) {
      final periods = context.readStore.timetable!.periods;
      if (periods.isNotEmpty) {
        final last = periods.reduce((a, b) => a.end > b.end ? a : b);
        _start = last.end;
        _end = last.end + (last.end - last.start);
      }
      _label.text = 'Period ${periods.where((p) => !p.isBreak).length + 1}';
    }
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final m = start ? _start : _end;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: context.use24h),
        child: child!,
      ),
    );
    if (t == null) return;
    setState(() => start ? _start = t.hour * 60 + t.minute : _end = t.hour * 60 + t.minute);
  }

  void _save() {
    if (_end <= _start) {
      context.toast('The period must end after it starts');
      return;
    }
    final p = Period(
      id: widget.period?.id,
      label: _label.text.trim().isEmpty ? (_isBreak ? 'Break' : 'Period') : _label.text.trim(),
      start: _start,
      end: _end,
      isBreak: _isBreak,
    );
    context.readStore.updateTimetable((t) {
      t.periods.removeWhere((x) => x.id == p.id);
      t.periods.add(p);
      t.periods.sort((a, b) => a.start.compareTo(b.start));
    });
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = context.timeFormat;
    return EditorScaffold(
      title: widget.period == null ? 'New period' : 'Edit period',
      onSave: _save,
      onDelete: widget.period == null
          ? null
          : () {
              context.readStore.updateTimetable(
                (t) => t.periods.removeWhere((p) => p.id == widget.period!.id),
              );
              Navigator.pop(context, true);
            },
      children: [
        TextField(
          controller: _label,
          decoration: const InputDecoration(labelText: 'Label'),
        ),
        Row(
          children: [
            Expanded(
              child: PickerField(
                label: 'Starts',
                value: fmt.minutes(_start),
                icon: Icons.schedule_rounded,
                onTap: () => _pick(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PickerField(
                label: 'Ends',
                value: fmt.minutes(_end),
                onTap: () => _pick(false),
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: const Text('This is a break'),
          subtitle: const Text('Lunch, recess… shown as a gap in your day'),
          value: _isBreak,
          onChanged: (v) => setState(() => _isBreak = v),
        ),
      ],
    );
  }
}

class TaskEditor extends StatefulWidget {
  const TaskEditor({super.key, this.task, this.subjectId});
  final StudyTask? task;
  final String? subjectId;

  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?.title);
  late final _notes = TextEditingController(text: widget.task?.notes);
  late TaskType _type = widget.task?.type ?? TaskType.assignment;
  late String? _subjectId = widget.task?.subjectId ?? widget.subjectId;
  late DateTime? _due = widget.task?.due ?? _defaultDue();
  late int _remind = widget.task?.remindBefore ?? 24 * 60;

  static DateTime _defaultDue() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + 1, 9);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final base = _due ?? _defaultDue();
    final d = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: context.use24h),
        child: child!,
      ),
    );
    setState(
      () => _due = DateTime(d.year, d.month, d.day, t?.hour ?? base.hour, t?.minute ?? base.minute),
    );
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final task = (widget.task ?? StudyTask(title: '')).copyWith(
      title: _title.text.trim(),
      type: _type,
      subjectId: _subjectId,
      clearSubject: _subjectId == null,
      due: _due,
      clearDue: _due == null,
      notes: _notes.text.trim(),
      remindBefore: _remind,
    );
    context.readStore.upsertTask(task);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final tt = context.store.timetable;
    final fmt = context.timeFormat;
    return EditorScaffold(
      title: widget.task == null ? 'New task' : 'Edit task',
      formKey: _form,
      onSave: _save,
      onDelete: widget.task == null
          ? null
          : () {
              context.readStore.removeTask(widget.task!.id);
              Navigator.pop(context, true);
            },
      children: [
        TextFormField(
          controller: _title,
          autofocus: widget.task == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'What needs doing?',
            hintText: 'e.g. Lab record 4',
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<TaskType>(
            showSelectedIcon: false,
            segments: [
              for (final t in TaskType.values) ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
        ),
        if (tt != null && tt.subjects.isNotEmpty) ...[
          const FieldLabel('Subject'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('None'),
                selected: _subjectId == null,
                onSelected: (_) => setState(() => _subjectId = null),
              ),
              for (final s in tt.subjects.where((s) => s.enrolled))
                ChoiceChip(
                  avatar: ColorDot(context.tone(s.color).accent),
                  label: Text(s.label),
                  selected: _subjectId == s.id,
                  onSelected: (_) => setState(() => _subjectId = s.id),
                ),
            ],
          ),
        ],
        Row(
          children: [
            Expanded(
              child: PickerField(
                label: 'Due',
                icon: Icons.event_outlined,
                value: _due == null
                    ? 'No due date'
                    : '${DateFormat('EEE, d MMM').format(_due!)} · ${fmt.time(_due!)}',
                onTap: _pickDue,
              ),
            ),
            if (_due != null)
              IconButton(
                tooltip: 'Remove due date',
                onPressed: () => setState(() => _due = null),
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
        if (_due != null)
          DropdownButtonFormField<int>(
            initialValue: _remind,
            decoration: const InputDecoration(
              labelText: 'Remind me',
              prefixIcon: Icon(Icons.notifications_outlined),
            ),
            items: [
              for (final m in const [-1, 0, 30, 60, 180, 1440, 2880, 10080])
                DropdownMenuItem(
                  value: m,
                  child: Text(m < 0 ? 'Don’t remind me' : leadTimeLabel(m)),
                ),
            ],
            onChanged: (v) => setState(() => _remind = v ?? _remind),
          ),
        TextField(
          controller: _notes,
          maxLines: 5,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Notes', alignLabelWithHint: true),
        ),
      ],
    );
  }
}

/// Renames a timetable and edits its details.
class TimetableDetailsEditor extends StatefulWidget {
  const TimetableDetailsEditor({super.key, required this.timetable, this.isNew = false});
  final Timetable timetable;
  final bool isNew;

  @override
  State<TimetableDetailsEditor> createState() => _TimetableDetailsEditorState();
}

class _TimetableDetailsEditorState extends State<TimetableDetailsEditor> {
  late final _name = TextEditingController(text: widget.timetable.name);
  late final _inst = TextEditingController(text: widget.timetable.institution);
  late final _section = TextEditingController(text: widget.timetable.section);
  late DateTime? _from = widget.timetable.validFrom;
  late DateTime? _until = widget.timetable.validUntil;
  late final Set<int> _days = {...widget.timetable.workingDays};
  late TimetableKind _kind = widget.timetable.kind;

  @override
  void dispose() {
    _name.dispose();
    _inst.dispose();
    _section.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime? initial) => showDatePicker(
    context: context,
    initialDate: initial ?? DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );

  void _save() {
    final store = context.readStore;
    void apply(Timetable t) {
      t
        ..name = _name.text.trim().isEmpty ? 'My timetable' : _name.text.trim()
        ..institution = _inst.text.trim().isEmpty ? null : _inst.text.trim()
        ..section = _section.text.trim().isEmpty ? null : _section.text.trim()
        ..validFrom = _from
        ..validUntil = _until
        ..workingDays = (_days.toList()..sort())
        ..kind = _kind;
    }

    if (widget.isNew) {
      apply(widget.timetable);
      store.addTimetable(widget.timetable);
    } else {
      store.update((d) => apply(d.timetables.firstWhere((t) => t.id == widget.timetable.id)));
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => EditorScaffold(
    title: widget.isNew ? 'New timetable' : 'Timetable details',
    saveLabel: widget.isNew ? 'Create' : 'Save',
    onSave: _save,
    children: [
      TextField(
        controller: _name,
        autofocus: widget.isNew,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Name',
          hintText: _kind == TimetableKind.school ? 'e.g. Semester 6' : 'e.g. My week',
        ),
      ),
      const FieldLabel('What is it for?'),
      SegmentedButton<TimetableKind>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: TimetableKind.school,
            icon: Icon(Icons.school_outlined),
            label: Text('School / college'),
          ),
          ButtonSegment(
            value: TimetableKind.routine,
            icon: Icon(Icons.work_outline_rounded),
            label: Text('Work & daily routine'),
          ),
        ],
        selected: {_kind},
        onSelectionChanged: (v) => setState(() {
          _kind = v.first;
          if (_kind == TimetableKind.routine && widget.isNew) _days.addAll([6, 7]);
        }),
      ),
      TextField(
        controller: _inst,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: _kind == TimetableKind.school
              ? 'School / university'
              : 'Organisation (optional)',
          prefixIcon: const Icon(Icons.account_balance_outlined),
        ),
      ),
      TextField(
        controller: _section,
        decoration: InputDecoration(
          labelText: _kind == TimetableKind.school
              ? 'Class / section'
              : 'Team / department (optional)',
          prefixIcon: const Icon(Icons.groups_outlined),
        ),
      ),
      FieldLabel(_kind == TimetableKind.school ? 'Working days' : 'Days shown in the week view'),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var d = 1; d <= 7; d++)
            FilterChip(
              showCheckmark: false,
              label: Text(weekdayShort(d)),
              selected: _days.contains(d),
              onSelected: (on) =>
                  setState(() => on ? _days.add(d) : (_days.length > 1 ? _days.remove(d) : null)),
            ),
        ],
      ),
      Row(
        children: [
          Expanded(
            child: PickerField(
              label: 'Starts on',
              value: _from == null ? 'Any time' : DateFormat('d MMM y').format(_from!),
              onTap: () async {
                final d = await _pickDate(_from);
                if (d != null) setState(() => _from = d);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PickerField(
              label: 'Ends on',
              value: _until == null ? 'Open-ended' : DateFormat('d MMM y').format(_until!),
              onTap: () async {
                final d = await _pickDate(_until);
                if (d != null) setState(() => _until = d);
              },
            ),
          ),
        ],
      ),
      if (_from != null || _until != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _from = null;
              _until = null;
            }),
            icon: const Icon(Icons.all_inclusive_rounded),
            label: const Text('Clear dates'),
          ),
        ),
      Text(
        'Outside these dates the timetable stays quiet — handy for exam weeks and vacations.',
        style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
      ),
    ],
  );
}
