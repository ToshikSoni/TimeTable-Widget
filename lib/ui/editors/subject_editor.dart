import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/palette.dart';
import '../app_scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'editor_scaffold.dart';
import 'teacher_editor.dart';

class SubjectEditor extends StatefulWidget {
  const SubjectEditor({super.key, this.subject});
  final Subject? subject;

  @override
  State<SubjectEditor> createState() => _SubjectEditorState();
}

class _SubjectEditorState extends State<SubjectEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.subject?.name);
  late final _code = TextEditingController(text: widget.subject?.code);
  late final _short = TextEditingController(text: widget.subject?.shortName);
  late final _room = TextEditingController(text: widget.subject?.room);
  late final _notes = TextEditingController(text: widget.subject?.notes);
  late int _color;
  String? _teacherId;
  late bool _enrolled;
  int? _reminder;

  @override
  void initState() {
    super.initState();
    final s = widget.subject;
    _teacherId = s?.teacherId;
    _enrolled = s?.enrolled ?? true;
    _reminder = s?.reminderMinutes;
    _color = s?.color ?? kSubjectPalette[0];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.subject == null) {
      // Pick the first colour not used yet.
      final used = context.readStore.timetable!.subjects.map((s) => s.color).toSet();
      _color = kSubjectPalette.firstWhere(
        (c) => !used.contains(c),
        orElse: () => kSubjectPalette[used.length % kSubjectPalette.length],
      );
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _code, _short, _room, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    String? clean(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final s = Subject(
      id: widget.subject?.id,
      name: _name.text.trim(),
      code: _code.text.trim(),
      shortName: clean(_short),
      color: _color,
      teacherId: _teacherId,
      room: clean(_room),
      enrolled: _enrolled,
      reminderMinutes: _reminder,
      notes: clean(_notes),
    );
    context.readStore.upsertSubject(s);
    Navigator.pop(context, s);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete ${widget.subject!.name}?',
      message: 'All of its classes will be removed from the timetable too.',
    );
    if (!ok || !mounted) return;
    context.readStore.removeSubject(widget.subject!.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tt = context.store.timetable!;
    final tone = context.tone(_color);
    return EditorScaffold(
      title: widget.subject == null ? 'New subject' : 'Edit subject',
      formKey: _form,
      onSave: _save,
      onDelete: widget.subject == null ? null : _delete,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: tone.container, borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: tone.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ListenableBuilder(
                  listenable: Listenable.merge([_name, _code]),
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _code.text.isEmpty ? 'CODE' : _code.text,
                        style: context.text.labelSmall?.copyWith(
                          color: tone.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _name.text.isEmpty ? 'Subject name' : _name.text,
                        style: context.text.titleMedium?.copyWith(color: tone.onContainer),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        TextFormField(
          controller: _name,
          autofocus: widget.subject == null,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Cloud Security'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Give the subject a name' : null,
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Code', hintText: 'CSE2636'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _short,
                decoration: const InputDecoration(labelText: 'Short name', hintText: 'Optional'),
              ),
            ),
          ],
        ),
        const FieldLabel('Colour'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in kSubjectPalette)
              _Swatch(
                color: context.tone(c).accent,
                selected: c == _color,
                onTap: () => setState(() => _color = c),
              ),
          ],
        ),
        DropdownButtonFormField<String?>(
          initialValue: _teacherId,
          decoration: const InputDecoration(
            labelText: 'Teacher',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            for (final t in tt.teachers)
              DropdownMenuItem(
                value: t.id,
                child: Text(t.code.isEmpty ? t.name : '${t.name} (${t.code})'),
              ),
            const DropdownMenuItem(value: '__new', child: Text('+ Add teacher…')),
          ],
          onChanged: (v) async {
            if (v == '__new') {
              final t = await showEditor<Teacher>(context, const TeacherEditor());
              setState(() => _teacherId = t?.id ?? _teacherId);
            } else {
              setState(() => _teacherId = v);
            }
          },
        ),
        TextField(
          controller: _room,
          decoration: const InputDecoration(
            labelText: 'Usual room',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
        DropdownButtonFormField<int?>(
          initialValue: _reminder,
          decoration: const InputDecoration(
            labelText: 'Reminder',
            prefixIcon: Icon(Icons.notifications_outlined),
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('Use default')),
            DropdownMenuItem(value: -1, child: Text('No reminders')),
            DropdownMenuItem(value: 0, child: Text('At start time')),
            DropdownMenuItem(value: 5, child: Text('5 minutes before')),
            DropdownMenuItem(value: 10, child: Text('10 minutes before')),
            DropdownMenuItem(value: 15, child: Text('15 minutes before')),
            DropdownMenuItem(value: 30, child: Text('30 minutes before')),
          ],
          onChanged: (v) => setState(() => _reminder = v),
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: const Text('I take this subject'),
          subtitle: const Text(
            'Turn off for electives you’re not enrolled in to hide their classes',
          ),
          value: _enrolled,
          onChanged: (v) => setState(() => _enrolled = v),
        ),
        TextField(
          controller: _notes,
          maxLines: 4,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Notes',
            hintText: 'Syllabus, books, links…',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkResponse(
    onTap: onTap,
    radius: 24,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? context.colors.onSurface : Colors.transparent,
          width: 2.5,
        ),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
      ),
    ),
  );
}
